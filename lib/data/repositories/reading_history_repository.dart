import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/reading_record.dart';
import 'package:sqflite/sqflite.dart';

/// One row per book: the last position the reader was at.
class ReadingHistoryRepository {
  ReadingHistoryRepository({ReaderDatabase? db})
    : _db = db ?? ReaderDatabase.instance;

  final ReaderDatabase _db;

  static final ReadingHistoryRepository instance = ReadingHistoryRepository();

  Future<Database> get _database => _db.database;

  Future<void> touch({
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    required String chapterName,
  }) async {
    if (bookId.isEmpty) return;
    final db = await _database;
    await db.insert('reading_history', {
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'page_index': pageIndex,
      'chapter_name': chapterName,
      'read_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 撤销删除：把刚才移除的那一行按原值写回（书架与进度不受影响）。
  Future<void> restore(ReadingRecord record) async {
    if (record.bookId.isEmpty) return;
    final db = await _database;
    await db.insert('reading_history', {
      'book_id': record.bookId,
      'chapter_index': record.chapterIndex,
      'page_index': record.pageIndex,
      'chapter_name': record.chapterName,
      'read_at': record.readAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReadingRecord>> recent({int limit = 100}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT h.*, b.name AS book_name, b.author, b.cover_url, b.book_url '
      'FROM reading_history h JOIN books b ON b.id = h.book_id '
      'ORDER BY h.read_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(ReadingRecord.fromRow).toList(growable: false);
  }

  /// 移除一条记录；书架、阅读进度与离线缓存都保留
  /// （对齐文库「只移记录」的语义）。再次阅读会自动重新出现。
  Future<void> remove(String bookId) async {
    if (bookId.isEmpty) return;
    final db = await _database;
    await db.delete(
      'reading_history',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('reading_history');
  }
}
