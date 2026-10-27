import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/reading_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 2.1.0 wiped reading history whenever a book left the shelf, because the
/// book row was deleted and `reading_history.book_id` cascades. Removing a
/// book must only flip `books.on_shelf`.
void main() {
  setUpAll(sqfliteFfiInit);

  test('移出书架保留书籍行与阅读记录，重新加入可恢复', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);

    final readerDb = ReaderDatabase.withDatabase(db);
    final books = BookRepository(db: readerDb);
    final history = ReadingHistoryRepository(db: readerDb);

    final book = Book(
      id: 'b1',
      name: '测试书',
      sourceUrl: 'https://source.example',
      bookUrl: 'https://source.example/book/1',
    );
    await books.upsert(book);
    await history.touch(
      bookId: 'b1',
      chapterIndex: 3,
      pageIndex: 1,
      chapterName: '第三章',
    );

    expect(await books.getAll(includeLocal: false), hasLength(1));
    expect(await history.recent(), hasLength(1));

    await books.retire(['b1']);

    // Off the shelf…
    expect(await books.getAll(includeLocal: false), isEmpty);
    // …but the row, the book and its history are still there.
    expect(await books.getById('b1'), isNotNull);
    final records = await history.recent();
    expect(records, hasLength(1));
    expect(records.first.chapterName, '第三章');

    // Adding it again must bring it back after a cold start.
    await books.setOnShelf(['b1'], true);
    expect(await books.getAll(includeLocal: false), hasLength(1));
  });

  test('history-only book (never on shelf) stays off the shelf', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);

    final readerDb = ReaderDatabase.withDatabase(db);
    final books = BookRepository(db: readerDb);

    await books.ensureExists(
      Book(
        id: 'b2',
        name: '只读过',
        sourceUrl: 'https://source.example',
        bookUrl: 'https://source.example/book/2',
      ),
    );

    expect(await books.getById('b2'), isNotNull);
    expect(await books.getAll(includeLocal: false), isEmpty);
  });
}
