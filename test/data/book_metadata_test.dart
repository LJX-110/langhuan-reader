import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('本地书信息修正只改书名 / 作者', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ReaderDatabase.createSchema(db);
    await db.insert('books', {
      'id': 'b1',
      'name': '旧书名',
      'author': '旧作者',
      'chapter_index': 7,
    });
    final repo = BookRepository(db: ReaderDatabase.withDatabase(db));

    await repo.updateMetadata(bookId: 'b1', name: '新书名', author: '新作者');

    final row = (await db.query(
      'books',
      where: 'id = ?',
      whereArgs: ['b1'],
    )).single;
    expect(row['name'], '新书名');
    expect(row['author'], '新作者');
    expect(row['chapter_index'], 7);
  });
}
