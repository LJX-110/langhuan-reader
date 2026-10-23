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

  Future<void> clear() async {
    final db = await _database;
    await db.delete('reading_history');
  }
}
