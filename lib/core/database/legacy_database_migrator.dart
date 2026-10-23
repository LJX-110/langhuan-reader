import 'dart:io';

import 'package:langhuan/core/utils/app_log.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Outcome of one legacy-database migration attempt.
enum LegacyMigrationStatus { targetExists, noLegacy, migrated, merged, failed }

class LegacyMigrationResult {
  const LegacyMigrationResult(
    this.status, {
    this.copiedRows = 0,
    this.legacyFiles = const [],
    this.error,
  });

  final LegacyMigrationStatus status;
  final int copiedRows;
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

  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns,
  );

  Future<void> insertIgnore(
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
    try {
      await backend.createReaderDatabase(temp);
      final targetTables = (await backend.tables(temp)).toSet();
      for (final source in legacy) {
        copiedRows += await _copyDatabase(source, temp, targetTables);
      }

      // Another isolated open won the race; keep the established database,
      // but leave a retry marker because its target may be freshly created.
      if (await backend.exists(target)) {
        await backend.delete(temp);
        await _writePending(marker, 'target appeared during migration');
        return LegacyMigrationResult(
          LegacyMigrationStatus.targetExists,
          copiedRows: copiedRows,
          legacyFiles: legacy,
        );
      }
      await backend.rename(temp, target);
      await _deleteQuietly(marker);
      AppLog.i(
        'Database',
        'legacy migration ok files=${legacy.length} rows=$copiedRows',
      );
      return LegacyMigrationResult(
        LegacyMigrationStatus.migrated,
        copiedRows: copiedRows,
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
    try {
      final targetTables = (await backend.tables(target)).toSet();
      for (final source in legacy) {
        copiedRows += await _copyDatabase(source, target, targetTables);
      }
      await _deleteQuietly(marker);
      AppLog.i(
        'Database',
        'legacy retry merge ok files=${legacy.length} rows=$copiedRows',
      );
      return LegacyMigrationResult(
        LegacyMigrationStatus.merged,
        copiedRows: copiedRows,
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

  Future<int> _copyDatabase(
    String source,
    String target,
    Set<String> targetTables,
  ) async {
    var copied = 0;
    final sourceTables = (await backend.tables(source)).toSet();
    for (final table in copyTables) {
      if (!targetTables.contains(table) || !sourceTables.contains(table)) {
        continue;
      }
      final targetColumns = (await backend.columns(target, table)).toSet();
      final sourceColumns = (await backend.columns(source, table)).toSet();
      final shared = sourceColumns.where(targetColumns.contains).toList();
      if (shared.isEmpty) continue;

      final rows = await backend.rows(source, table, shared);
      if (rows.isEmpty) continue;
      await backend.insertIgnore(target, table, rows);
      copied += rows.length;
    }
    return copied;
  }
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
  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns,
  ) async {
    final db = await _database(path);
    return db.query(table, columns: columns);
  }

  @override
  Future<void> insertIgnore(
    String path,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    final db = await _database(path);
    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
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
