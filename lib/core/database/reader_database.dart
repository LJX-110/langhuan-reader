import 'package:langhuan/core/database/legacy_database_migrator.dart';
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

  /// Schema version. Bumped when tables change. Upgrades are incremental —
  /// never drop user data (see [_onUpgrade]).
  static const int version = 3;
  static const String fileName = 'reader.db';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
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
    return openDatabase(
      path,
      version: version,
      onCreate: (db, v) => createSchema(db),
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Build the complete v3 schema. Shared with the migration backend.
  static Future<void> createSchema(Database db) async {
    await _createBooks(db);
    await _createChapters(db);
    await _createSources(db);
    await _createBookmarks(db);
    await _createReadingHistory(db);
  }

  /// Additive migrations only. Existing books / chapters / sources stay intact.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _createBookmarks(db);
      await _createReadingHistory(db);
    }
  }

  static Future<void> _createBooks(Database db) async {
    await db.execute('''
CREATE TABLE books (
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
    await db.execute('CREATE INDEX idx_books_sort ON books (sort_time DESC)');
  }

  static Future<void> _createChapters(Database db) async {
    await db.execute('''
CREATE TABLE chapters (
  id TEXT PRIMARY KEY NOT NULL,
  book_id TEXT NOT NULL,
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
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
    await db.execute('CREATE INDEX idx_chapters_book ON chapters (book_id)');
    await db.execute(
      'CREATE UNIQUE INDEX idx_chapters_book_ord ON chapters (book_id, ord)',
    );
    await db.execute('CREATE INDEX idx_chapters_url ON chapters (url)');
  }

  static Future<void> _createSources(Database db) async {
    await db.execute('''
CREATE TABLE sources (
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
    await db.execute(
      'CREATE INDEX idx_sources_order ON sources (custom_order ASC)',
    );
  }

  static Future<void> _createBookmarks(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS bookmarks (
  id TEXT PRIMARY KEY NOT NULL,
  book_id TEXT NOT NULL,
  chapter_index INTEGER NOT NULL DEFAULT 0,
  page_index INTEGER NOT NULL DEFAULT 0,
  chapter_name TEXT NOT NULL DEFAULT '',
  excerpt TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_read '
      'ON reading_history (read_at DESC)',
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
