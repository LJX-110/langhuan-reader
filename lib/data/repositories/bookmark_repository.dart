import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/bookmark.dart';
import 'package:sqflite/sqflite.dart';

/// Page bookmarks, persisted per book.
class BookmarkRepository {
  BookmarkRepository({ReaderDatabase? db})
    : _db = db ?? ReaderDatabase.instance;

  final ReaderDatabase _db;

  static final BookmarkRepository instance = BookmarkRepository();

  Future<Database> get _database => _db.database;

  Future<bool> exists(String id) async {
    final db = await _database;
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> add(Bookmark bookmark) async {
    final db = await _database;
    await db.insert(
      'bookmarks',
      bookmark.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String id) async {
    final db = await _database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Bookmark>> forBook(String bookId) async {
    final db = await _database;
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC, page_index ASC',
    );
    return rows.map(Bookmark.fromRow).toList(growable: false);
  }
}
