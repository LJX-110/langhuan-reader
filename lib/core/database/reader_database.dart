import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:langhuan/core/database/legacy_database_migrator.dart';
import 'package:langhuan/core/database/legacy_schema_mapping.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for 琅嬛阁.
///
/// Holds shelf (`books`), chapter cache (`chapters`), and book sources
/// (`sources`). Legacy multi-file databases are imported once, non-destructively,
/// when this file is first created (see [LegacyDatabaseMigrator]).
class ReaderDatabase {
  ReaderDatabase._();
  static final ReaderDatabase instance = ReaderDatabase._();

  /// Test-only instance backed by an already-open database.
  ReaderDatabase.withDatabase(Database db) : _db = db;

  /// Schema version. Bumped when tables change. Upgrades are incremental —
  /// never drop user data (see [_onUpgrade]).
  ///
  /// v4: `chapters` gains `volume_title` / `volume_ord` for grouped TOCs.
  static const int version = 4;
  static const String fileName = 'reader.db';

  /// One-time guard so an old `sources.db` is imported after a v1 `reader.db`
  /// upgrade even when the main migrator cannot see the missing table yet.
  static const String sourcesCheckedMarker = 'reader.db.sources_imported';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final opening = _opening;
    if (opening != null) return opening;

    final future = _open();
    _opening = future;
    try {
      final db = await future;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    // A failed import leaves reader.db.migration_pending; the next launch
    // merges the legacy rows into the freshly created reader.db.
    await LegacyDatabaseMigrator(
      backend: SqfliteLegacyMigrationBackend(
        createSchema: createSchema,
        version: version,
      ),
    ).migrate(dir.path);
    final path = p.join(dir.path, fileName);
    // Capture whether `sources` already existed *before* createSchema repairs
    // the file. If it existed, an empty table means the user deleted their
    // sources and sources.db must not be resurrected.
    final hadSourcesTable = await _hadSourcesTableBeforeOpen(path);
    final db = await openDatabase(
      path,
      version: version,
      onCreate: (db, v) => createSchema(db),
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    // A previous 1.0.x build could leave an upgraded reader.db with a missing
    // sources table because its _onUpgrade was incomplete. All statements are
    // idempotent, so run the schema once per open to repair that state.
    await createSchema(db);
    await _importLegacySourcesOnce(
      db,
      dir.path,
      hadSourcesTable: hadSourcesTable,
    );
    return db;
  }

  /// Build the complete v3 schema. Shared with the migration backend.
  ///
  /// Every statement is `IF NOT EXISTS` plus an additive column check, so this
  /// also repairs a v1 `reader.db` that only had `books` and `chapters`.
  static Future<void> createSchema(Database db) async {
    await _createBooks(db);
    await _createChapters(db);
    await _createSources(db);
    await _createBookmarks(db);
    await _createReadingHistory(db);
  }

  /// Additive migrations only. Existing books / chapters / sources stay intact.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await createSchema(db);
  }

  static Future<void> _createBooks(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS books (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  author TEXT NOT NULL DEFAULT '',
  cover_url TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  source_url TEXT NOT NULL DEFAULT '',
  book_url TEXT NOT NULL DEFAULT '',
  origin_name TEXT NOT NULL DEFAULT '',
  toc_url TEXT NOT NULL DEFAULT '',
  chapter_index INTEGER NOT NULL DEFAULT 0,
  page_index INTEGER NOT NULL DEFAULT 0,
  scroll_offset REAL NOT NULL DEFAULT 0,
  reading_chapter TEXT NOT NULL DEFAULT '',
  latest_chapter TEXT NOT NULL DEFAULT '',
  sort_time INTEGER NOT NULL DEFAULT 0,
  has_update INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT ''
)''');
    await _ensureColumns(db, 'books', const {
      'name': "TEXT NOT NULL DEFAULT ''",
      'author': "TEXT NOT NULL DEFAULT ''",
      'cover_url': "TEXT NOT NULL DEFAULT ''",
      'category': "TEXT NOT NULL DEFAULT ''",
      'description': "TEXT NOT NULL DEFAULT ''",
      'source_url': "TEXT NOT NULL DEFAULT ''",
      'book_url': "TEXT NOT NULL DEFAULT ''",
      'origin_name': "TEXT NOT NULL DEFAULT ''",
      'toc_url': "TEXT NOT NULL DEFAULT ''",
      'chapter_index': 'INTEGER NOT NULL DEFAULT 0',
      'page_index': 'INTEGER NOT NULL DEFAULT 0',
      'scroll_offset': 'REAL NOT NULL DEFAULT 0',
      'reading_chapter': "TEXT NOT NULL DEFAULT ''",
      'latest_chapter': "TEXT NOT NULL DEFAULT ''",
      'sort_time': 'INTEGER NOT NULL DEFAULT 0',
      'has_update': 'INTEGER NOT NULL DEFAULT 0',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    });
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_sort ON books (sort_time DESC)',
    );
  }

  static Future<void> _createChapters(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS chapters (
  id TEXT PRIMARY KEY NOT NULL,
  book_id TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL DEFAULT '',
  url TEXT NOT NULL DEFAULT '',
  source_url TEXT NOT NULL DEFAULT '',
  ord INTEGER NOT NULL DEFAULT 0,
  body TEXT NOT NULL DEFAULT '',
  has_body INTEGER NOT NULL DEFAULT 0,
  content_len INTEGER NOT NULL DEFAULT 0,
  pages_json TEXT,
  layout_fp TEXT,
  pages_cached_at INTEGER NOT NULL DEFAULT 0,
  volume_title TEXT NOT NULL DEFAULT '',
  volume_ord INTEGER NOT NULL DEFAULT -1,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
    await _ensureColumns(db, 'chapters', const {
      'book_id': "TEXT NOT NULL DEFAULT ''",
      'title': "TEXT NOT NULL DEFAULT ''",
      'url': "TEXT NOT NULL DEFAULT ''",
      'source_url': "TEXT NOT NULL DEFAULT ''",
      'ord': 'INTEGER NOT NULL DEFAULT 0',
      'body': "TEXT NOT NULL DEFAULT ''",
      'has_body': 'INTEGER NOT NULL DEFAULT 0',
      'content_len': 'INTEGER NOT NULL DEFAULT 0',
      'pages_json': 'TEXT',
      'layout_fp': 'TEXT',
      'pages_cached_at': 'INTEGER NOT NULL DEFAULT 0',
      'volume_title': "TEXT NOT NULL DEFAULT ''",
      'volume_ord': 'INTEGER NOT NULL DEFAULT -1',
    });
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters (book_id)',
    );
    await _ensureUniqueChapterOrd(db);
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_chapters_book_ord '
      'ON chapters (book_id, ord)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chapters_url ON chapters (url)',
    );
  }

  static Future<void> _createSources(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sources (
  book_source_url TEXT PRIMARY KEY NOT NULL,
  book_source_name TEXT NOT NULL DEFAULT '',
  book_source_group TEXT NOT NULL DEFAULT '',
  book_source_type INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  custom_order INTEGER NOT NULL DEFAULT 0,
  weight INTEGER NOT NULL DEFAULT 0,
  search_url TEXT NOT NULL DEFAULT '',
  explore_url TEXT NOT NULL DEFAULT '',
  header TEXT NOT NULL DEFAULT '',
  raw_json TEXT NOT NULL DEFAULT '',
  last_update_time INTEGER NOT NULL DEFAULT 0,
  respond_time INTEGER NOT NULL DEFAULT 0,
  last_check_time INTEGER NOT NULL DEFAULT 0
)''');
    await _ensureColumns(db, 'sources', const {
      'book_source_name': "TEXT NOT NULL DEFAULT ''",
      'book_source_group': "TEXT NOT NULL DEFAULT ''",
      'book_source_type': 'INTEGER NOT NULL DEFAULT 0',
      'enabled': 'INTEGER NOT NULL DEFAULT 1',
      'custom_order': 'INTEGER NOT NULL DEFAULT 0',
      'weight': 'INTEGER NOT NULL DEFAULT 0',
      'search_url': "TEXT NOT NULL DEFAULT ''",
      'explore_url': "TEXT NOT NULL DEFAULT ''",
      'header': "TEXT NOT NULL DEFAULT ''",
      'raw_json': "TEXT NOT NULL DEFAULT ''",
      'last_update_time': 'INTEGER NOT NULL DEFAULT 0',
      'respond_time': 'INTEGER NOT NULL DEFAULT 0',
      'last_check_time': 'INTEGER NOT NULL DEFAULT 0',
    });
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sources_order '
      'ON sources (custom_order ASC)',
    );
  }

  static Future<void> _createBookmarks(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS bookmarks (
  id TEXT PRIMARY KEY NOT NULL,
  book_id TEXT NOT NULL DEFAULT '',
  chapter_index INTEGER NOT NULL DEFAULT 0,
  page_index INTEGER NOT NULL DEFAULT 0,
  chapter_name TEXT NOT NULL DEFAULT '',
  excerpt TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
    await _ensureColumns(db, 'bookmarks', const {
      'book_id': "TEXT NOT NULL DEFAULT ''",
      'chapter_index': 'INTEGER NOT NULL DEFAULT 0',
      'page_index': 'INTEGER NOT NULL DEFAULT 0',
      'chapter_name': "TEXT NOT NULL DEFAULT ''",
      'excerpt': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'INTEGER NOT NULL DEFAULT 0',
    });
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book '
      'ON bookmarks (book_id, chapter_index, page_index)',
    );
  }

  static Future<void> _createReadingHistory(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS reading_history (
  book_id TEXT PRIMARY KEY NOT NULL,
  chapter_index INTEGER NOT NULL DEFAULT 0,
  page_index INTEGER NOT NULL DEFAULT 0,
  chapter_name TEXT NOT NULL DEFAULT '',
  read_at INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
    await _ensureColumns(db, 'reading_history', const {
      'chapter_index': 'INTEGER NOT NULL DEFAULT 0',
      'page_index': 'INTEGER NOT NULL DEFAULT 0',
      'chapter_name': "TEXT NOT NULL DEFAULT ''",
      'read_at': 'INTEGER NOT NULL DEFAULT 0',
    });
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_read '
      'ON reading_history (read_at DESC)',
    );
  }

  /// Add missing columns to a legacy table without touching existing rows.
  static Future<void> _ensureColumns(
    Database db,
    String table,
    Map<String, String> definitions,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final existing = rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    for (final entry in definitions.entries) {
      if (existing.contains(entry.key)) continue;
      await db.execute(
        'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }

  /// Old reader.db files can contain duplicate `(book_id, ord)` pairs. Without
  /// this, the unique index below would fail and the app could not open.
  /// Renumber each book's rows in their existing order; no row is removed.
  static Future<void> _ensureUniqueChapterOrd(Database db) async {
    final duplicates = await db.rawQuery(
      'SELECT 1 FROM chapters GROUP BY book_id, ord HAVING COUNT(*) > 1 LIMIT 1',
    );
    if (duplicates.isEmpty) return;
    final rows = await db.query(
      'chapters',
      columns: ['rowid', 'book_id'],
      orderBy: 'book_id ASC, ord ASC, rowid ASC',
    );
    final batch = db.batch();
    var currentBook = '';
    var next = 0;
    for (final row in rows) {
      final bookId = row['book_id']?.toString() ?? '';
      if (bookId != currentBook) {
        currentBook = bookId;
        next = 0;
      }
      batch.update(
        'chapters',
        {'ord': next},
        where: 'rowid = ?',
        whereArgs: [row['rowid']],
      );
      next++;
    }
    await batch.commit(noResult: true);
    AppLog.w(
      'Database',
      'duplicate chapter ord renumbered before unique index creation',
    );
  }

  /// Whether a legacy `sources.db` should be imported on this open.
  ///
  /// Only true when no marker exists, the current reader.db never had a
  /// `sources` table, and the legacy file is present. This keeps a user who
  /// deleted every source from getting them restored.
  static bool shouldImportLegacySources({
    required bool markerExists,
    required bool hadSourcesTable,
    required bool legacyFileExists,
  }) => !markerExists && !hadSourcesTable && legacyFileExists;

  Future<bool> _hadSourcesTableBeforeOpen(String path) async {
    if (!await File(path).exists()) return false;
    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true, singleInstance: false);
      final rows = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'sources' LIMIT 1",
      );
      return rows.isNotEmpty;
    } catch (e) {
      AppLog.w(
        'Database',
        'could not probe sources table before open; skipping legacy import',
        error: e,
      );
      // Assume it existed: prefer not to resurrect a deleted source list.
      return true;
    } finally {
      try {
        await probe?.close();
      } catch (_) {}
    }
  }

  /// Import `sources.db` exactly once after a v1 `reader.db` upgrade.
  ///
  /// The main migrator runs before [openDatabase] and sees the old reader.db,
  /// so it cannot import into the newly added `sources` table. This repair
  /// runs after the schema exists, only when the table was genuinely missing,
  /// and records a marker so a user-deleted source list is never resurrected.
  Future<void> _importLegacySourcesOnce(
    Database db,
    String dir, {
    required bool hadSourcesTable,
  }) async {
    final marker = File(p.join(dir, sourcesCheckedMarker));
    if (await marker.exists()) return;
    final legacyPath = p.join(dir, 'sources.db');
    final legacyExists = await File(legacyPath).exists();
    if (!shouldImportLegacySources(
      markerExists: false,
      hadSourcesTable: hadSourcesTable,
      legacyFileExists: legacyExists,
    )) {
      await _writeSourcesMarker(
        marker,
        hadSourcesTable ? 'already-present' : 'no-legacy',
      );
      return;
    }
    Database? legacy;
    try {
      legacy = await openDatabase(
        legacyPath,
        readOnly: true,
        singleInstance: false,
      );
      final table = await legacy.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name = 'sources' LIMIT 1",
      );
      if (table.isEmpty) {
        await _writeSourcesMarker(marker, 'no-table');
        return;
      }
      final rows = await legacy.query('sources');
      // The whole batch lands in one transaction: an interrupted import
      // leaves no half-written source list, and the next launch re-runs the
      // rows it had already written because INSERT OR IGNORE is idempotent.
      final stats = await insertLegacySources(db, rows);
      await _writeSourcesMarker(
        marker,
        'imported=${stats.inserted} invalid=${stats.invalid}',
      );
      AppLog.i(
        'Database',
        'legacy sources checked imported=${stats.inserted} '
            'invalid=${stats.invalid}',
      );
    } catch (e, st) {
      AppLog.e(
        'Database',
        'legacy sources import failed; will retry next launch',
        error: e,
        stackTrace: st,
      );
    } finally {
      try {
        await legacy?.close();
      } catch (_) {}
    }
  }

  /// Map legacy source rows and insert them in one transaction.
  ///
  /// Returns how many rows were newly inserted and how many lacked a usable
  /// identity. Rows already present keep their local state.
  @visibleForTesting
  static Future<({int inserted, int invalid})> insertLegacySources(
    Database db,
    List<Map<String, Object?>> legacyRows,
  ) async {
    var invalid = 0;
    final mappedRows = <Map<String, Object?>>[];
    for (final row in legacyRows) {
      final mapped = LegacySchemaMapping.source(row);
      if (mapped == null) {
        invalid++;
        continue;
      }
      mappedRows.add(mapped);
    }
    final before = await _count(db, 'sources');
    await db.transaction((txn) async {
      for (final row in mappedRows) {
        await txn.insert(
          'sources',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    final after = await _count(db, 'sources');
    return (inserted: after - before, invalid: invalid);
  }

  static Future<void> _writeSourcesMarker(File marker, String text) async {
    try {
      await marker.writeAsString('$text\n', flush: true);
    } catch (e) {
      AppLog.w('Database', 'could not write sources marker', error: e);
    }
  }

  static Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    final value = rows.isEmpty ? null : rows.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
