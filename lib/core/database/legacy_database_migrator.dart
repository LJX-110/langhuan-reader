import 'dart:io';

import 'package:langhuan/core/database/legacy_schema_mapping.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Outcome of one legacy-database migration attempt.
enum LegacyMigrationStatus { targetExists, noLegacy, migrated, merged, failed }

/// A row that cannot be mapped without losing its identity or a constraint
/// conflict that means the target already lost data during an older build.
class LegacyMigrationException implements Exception {
  const LegacyMigrationException(this.message);

  final String message;

  @override
  String toString() => 'LegacyMigrationException: $message';
}

class LegacyMigrationResult {
  const LegacyMigrationResult(
    this.status, {
    this.copiedRows = 0,
    this.skippedRows = 0,
    this.legacyFiles = const [],
    this.error,
  });

  final LegacyMigrationStatus status;

  /// Rows actually inserted by the last migration call.
  final int copiedRows;

  /// Duplicate or already-present rows skipped by `INSERT OR IGNORE`.
  final int skippedRows;

  final List<String> legacyFiles;
  final Object? error;
}

/// Storage operations used by [LegacyDatabaseMigrator].
///
/// Abstracted so migration rules can be unit-tested without sqflite, which
/// is not available on the host test VM.
abstract class LegacyMigrationBackend {
  Future<bool> exists(String path);

  Future<void> delete(String path);

  Future<void> rename(String from, String to);

  /// Create [path] with the current reader schema.
  Future<void> createReaderDatabase(String path);

  Future<List<String>> tables(String path);

  Future<List<String>> columns(String path, String table);

  Future<int> count(String path, String table);

  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns, {
    int? limit,
    int? offset,
    String? orderBy,
  });

  /// Insert rows, skipping primary-key / unique-index conflicts.
  ///
  /// Returns the number of rows actually inserted, so a migration cannot
  /// report success while every row was silently ignored.
  Future<int> insertIgnore(
    String path,
    String table,
    List<Map<String, Object?>> rows,
  );

  /// Write a small marker file (used to retry a failed import next launch).
  Future<void> writeText(String path, String text);

  Future<void> closeAll();
}

/// One-time, non-destructive import from the old multi-file databases.
///
/// The legacy schema was never part of this repository, so the import is
/// introspective: only tables and columns that exist in both the legacy file
/// and the current schema are copied. Source files are never deleted or
/// renamed; if anything fails they stay exactly where they were.
class LegacyDatabaseMigrator {
  LegacyDatabaseMigrator({required this.backend});

  final LegacyMigrationBackend backend;

  static const String targetFileName = 'reader.db';
  static const String pendingFileName = 'reader.db.migration_pending';
  static const String tempSuffix = '.migrating';

  /// Parent-first order keeps foreign-key relationships valid.
  static const List<String> copyTables = [
    'books',
    'sources',
    'chapters',
    'bookmarks',
    'reading_history',
  ];

  static const List<String> legacyFileNames = [
    'books.db',
    'chapters.db',
    'sources.db',
  ];

  Future<LegacyMigrationResult> migrate(String directory) async {
    final target = p.join(directory, targetFileName);
    final marker = p.join(directory, pendingFileName);
    final legacy = <String>[];
    for (final name in legacyFileNames) {
      final path = p.join(directory, name);
      if (await backend.exists(path)) legacy.add(path);
    }

    if (await backend.exists(target)) {
      if (await backend.exists(marker)) {
        if (legacy.isEmpty) {
          await _deleteQuietly(marker);
          return const LegacyMigrationResult(
            LegacyMigrationStatus.targetExists,
          );
        }
        return _mergeInto(target, marker, legacy);
      }
      return const LegacyMigrationResult(LegacyMigrationStatus.targetExists);
    }

    if (legacy.isEmpty) {
      // A marker without legacy files means there is nothing left to import.
      await _deleteQuietly(marker);
      return const LegacyMigrationResult(LegacyMigrationStatus.noLegacy);
    }

    final temp = '$target$tempSuffix';
    // A previous interrupted attempt left our scratch file behind; replacing
    // it cannot touch user data.
    if (await backend.exists(temp)) {
      await backend.delete(temp);
    }

    var copiedRows = 0;
    var skippedRows = 0;
    try {
      await backend.createReaderDatabase(temp);
      final targetTables = (await backend.tables(temp)).toSet();
      for (final source in legacy) {
        final stats = await _copyDatabase(
          source,
          temp,
          targetTables,
          allowConflicts: false,
        );
        copiedRows += stats.inserted;
        skippedRows += stats.skipped;
      }

      // Another isolated open won the race; keep the established database,
      // but leave a retry marker because its target may be freshly created.
      if (await backend.exists(target)) {
        await backend.delete(temp);
        await _writePending(marker, 'target appeared during migration');
        return LegacyMigrationResult(
          LegacyMigrationStatus.targetExists,
          copiedRows: copiedRows,
          skippedRows: skippedRows,
          legacyFiles: legacy,
        );
      }
      await backend.rename(temp, target);
      await _deleteQuietly(marker);
      AppLog.i(
        'Database',
        'legacy migration ok files=${legacy.length} '
            'inserted=$copiedRows skipped=$skippedRows',
      );
      return LegacyMigrationResult(
        LegacyMigrationStatus.migrated,
        copiedRows: copiedRows,
        skippedRows: skippedRows,
        legacyFiles: legacy,
      );
    } catch (e, st) {
      AppLog.e(
        'Database',
        'legacy migration failed; source files kept untouched, retry next launch',
        error: e,
        stackTrace: st,
      );
      try {
        await backend.closeAll();
        if (await backend.exists(temp)) await backend.delete(temp);
      } catch (_) {}
      await _writePending(marker, e);
      return LegacyMigrationResult(
        LegacyMigrationStatus.failed,
        copiedRows: copiedRows,
        skippedRows: skippedRows,
        legacyFiles: legacy,
        error: e,
      );
    } finally {
      try {
        await backend.closeAll();
      } catch (_) {}
    }
  }

  /// Import legacy rows into an existing database after a failed first attempt.
  ///
  /// [LegacyMigrationBackend.insertIgnore] makes this idempotent: rows the user
  /// has already created in reader.db win, and a retry can run safely on every
  /// launch until it succeeds.
  Future<LegacyMigrationResult> _mergeInto(
    String target,
    String marker,
    List<String> legacy,
  ) async {
    var copiedRows = 0;
    var skippedRows = 0;
    try {
      final targetTables = (await backend.tables(target)).toSet();
      for (final source in legacy) {
        final stats = await _copyDatabase(
          source,
          target,
          targetTables,
          allowConflicts: true,
        );
        copiedRows += stats.inserted;
        skippedRows += stats.skipped;
      }
      await _deleteQuietly(marker);
      AppLog.i(
        'Database',
        'legacy retry merge ok files=${legacy.length} '
            'inserted=$copiedRows skipped=$skippedRows',
      );
      return LegacyMigrationResult(
        LegacyMigrationStatus.merged,
        copiedRows: copiedRows,
        skippedRows: skippedRows,
        legacyFiles: legacy,
      );
    } catch (e, st) {
      AppLog.e(
        'Database',
        'legacy retry merge failed; retry marker kept',
        error: e,
        stackTrace: st,
      );
      await _writePending(marker, e);
      return LegacyMigrationResult(
        LegacyMigrationStatus.failed,
        copiedRows: copiedRows,
        skippedRows: skippedRows,
        legacyFiles: legacy,
        error: e,
      );
    } finally {
      try {
        await backend.closeAll();
      } catch (_) {}
    }
  }

  Future<void> _writePending(String marker, Object error) async {
    try {
      await backend.writeText(
        marker,
        '${DateTime.now().toUtc().toIso8601String()}\n$error',
      );
    } catch (e) {
      AppLog.w('Database', 'could not write migration marker', error: e);
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      if (await backend.exists(path)) await backend.delete(path);
    } catch (_) {}
  }

  Future<_CopyStats> _copyDatabase(
    String source,
    String target,
    Set<String> targetTables, {
    required bool allowConflicts,
  }) async {
    var inserted = 0;
    var skipped = 0;
    final sourceTables = (await backend.tables(source)).toSet();
    for (final table in copyTables) {
      if (!targetTables.contains(table) || !sourceTables.contains(table)) {
        continue;
      }
      final targetColumns = (await backend.columns(target, table)).toSet();
      final sourceColumns = await backend.columns(source, table);
      if (sourceColumns.isEmpty || targetColumns.isEmpty) continue;
      final stats = await _copyTable(
        source,
        target,
        table,
        sourceColumns,
        targetColumns,
        allowConflicts: allowConflicts,
      );
      inserted += stats.inserted;
      skipped += stats.skipped;
    }
    return _CopyStats(inserted: inserted, skipped: skipped);
  }

  Future<_CopyStats> _copyTable(
    String source,
    String target,
    String table,
    List<String> sourceColumns,
    Set<String> targetColumns, {
    required bool allowConflicts,
  }) async {
    // Chapters hold whole chapter bodies; keep each page small enough that a
    // legacy 100 MB chapters.db never has to be resident in memory at once.
    final pageSize = table == 'chapters' ? 50 : 200;
    final orderBy = _orderByFor(table, sourceColumns);
    final chapterOrd = <String, int>{};
    var offset = 0;
    var inserted = 0;
    var skipped = 0;

    while (true) {
      final rows = await backend.rows(
        source,
        table,
        sourceColumns,
        limit: pageSize,
        offset: offset,
        orderBy: orderBy,
      );
      if (rows.isEmpty) break;

      final mapped = <Map<String, Object?>>[];
      for (final row in rows) {
        final targetRow = _mapRow(table, row, chapterOrd);
        if (targetRow == null) {
          throw LegacyMigrationException(
            '$table row ${offset + mapped.length} has no usable identity; '
            'legacy file kept: $source',
          );
        }
        // Keep only columns the current target table actually owns.
        targetRow.removeWhere((key, _) => !targetColumns.contains(key));
        mapped.add(targetRow);
      }

      if (mapped.isNotEmpty) {
        final count = await backend.insertIgnore(target, table, mapped);
        inserted += count;
        final conflicts = mapped.length - count;
        if (conflicts > 0) {
          skipped += conflicts;
          if (!allowConflicts) {
            AppLog.w(
              'Database',
              'legacy $table: $conflicts row(s) skipped by a duplicate key',
            );
          }
        }
      }

      if (rows.length < pageSize) break;
      offset += pageSize;
    }

    return _CopyStats(inserted: inserted, skipped: skipped);
  }

  Map<String, Object?>? _mapRow(
    String table,
    Map<String, Object?> row,
    Map<String, int> chapterOrd,
  ) {
    switch (table) {
      case 'books':
        return LegacySchemaMapping.book(row);
      case 'chapters':
        final bookId = LegacySchemaMapping.stringOf(row, const [
          'book_id',
          'bookId',
        ]);
        final ord = chapterOrd[bookId] ?? 0;
        chapterOrd[bookId] = ord + 1;
        return LegacySchemaMapping.chapter(row, ord: ord);
      case 'sources':
        return LegacySchemaMapping.source(row);
      case 'bookmarks':
        return LegacySchemaMapping.bookmark(row);
      case 'reading_history':
        return LegacySchemaMapping.readingHistory(row);
    }
    return null;
  }

  static String? _orderByFor(String table, List<String> columns) {
    if (table != 'chapters') return 'rowid ASC';
    final parts = <String>[];
    if (columns.contains('book_id')) parts.add('book_id ASC');
    if (columns.contains('idx')) parts.add('idx ASC');
    parts.add('rowid ASC');
    return parts.join(', ');
  }
}

class _CopyStats {
  const _CopyStats({required this.inserted, required this.skipped});

  final int inserted;
  final int skipped;
}

/// Production backend: opens each database lazily with sqflite.
class SqfliteLegacyMigrationBackend implements LegacyMigrationBackend {
  SqfliteLegacyMigrationBackend({
    required this.createSchema,
    required this.version,
  });

  /// Builds the current schema ([ReaderDatabase.createSchema]).
  final Future<void> Function(Database db) createSchema;
  final int version;
  final Map<String, Database> _open = {};

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) async {
    final db = _open.remove(path);
    if (db != null) await db.close();
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> rename(String from, String to) async {
    final db = _open.remove(from);
    if (db != null) await db.close();
    await File(from).rename(to);
  }

  @override
  Future<void> createReaderDatabase(String path) async {
    final db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) => createSchema(db),
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = OFF'),
      singleInstance: false,
    );
    _open[path] = db;
  }

  @override
  Future<List<String>> tables(String path) async {
    final db = await _database(path);
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    return rows
        .map((r) => r['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<List<String>> columns(String path, String table) async {
    final db = await _database(path);
    final rows = await db.rawQuery('PRAGMA table_info(${_quote(table)})');
    return rows
        .map((r) => r['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<int> count(String path, String table) async {
    final db = await _database(path);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${_quote(table)}',
    );
    final value = rows.isEmpty ? null : rows.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns, {
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    final db = await _database(path);
    return db.query(
      table,
      columns: columns,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> insertIgnore(
    String path,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final db = await _database(path);
    final before = await count(path, table);
    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    final after = await count(path, table);
    return after - before;
  }

  @override
  Future<void> closeAll() async {
    for (final db in _open.values) {
      try {
        await db.close();
      } catch (_) {}
    }
    _open.clear();
  }

  @override
  Future<void> writeText(String path, String text) async {
    await File(path).writeAsString(text, flush: true);
  }

  Future<Database> _database(String path) async {
    final existing = _open[path];
    if (existing != null) return existing;
    final db = await openDatabase(
      path,
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = OFF'),
    );
    _open[path] = db;
    return db;
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';
}
