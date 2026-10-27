import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/features/reader/model/toc_service.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `ruleToc.updateTime`（章节字数 / 更新时间）must survive the whole chain:
/// engine chapter → TOC entry → chapters.info → reader header.
void main() {
  setUpAll(sqfliteFfiInit);

  test('mapChapters carries source chapter info', () {
    final book = Book(id: 'b1', name: '书', sourceUrl: 'https://s.example');
    final entries = TocService.mapChapters(book, [
      SourceChapter(name: '第一章', url: '/1', info: '章节字数：2345　更新时间：2022-12-04'),
      SourceChapter(name: '第二章', url: '/2'),
    ]);
    expect(entries, hasLength(2));
    expect(entries[0].info, contains('2345'));
    expect(entries[1].info, isEmpty);
  });

  test('chapters.info round-trips through syncToc and getToc', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);

    final readerDb = ReaderDatabase.withDatabase(db);
    final chapters = ChapterRepository(db: readerDb);
    await BookRepository(db: readerDb).upsert(
      Book(id: 'b1', name: '书', sourceUrl: 'https://s.example'),
    );

    await chapters.syncToc([
      ChapterTocEntry(
        id: 'c1',
        title: '第一章',
        url: 'https://s.example/1',
        ord: 0,
        info: '章节字数：2345字　更新时间：2022-12-04',
      ),
    ], 'b1', sourceUrl: 'https://s.example');

    final loaded = await chapters.getToc('b1');
    expect(loaded, hasLength(1));
    expect(loaded.first.info, '章节字数：2345字　更新时间：2022-12-04');

    // Re-sync with a new info value must update, not duplicate.
    await chapters.syncToc([
      ChapterTocEntry(
        id: 'c1',
        title: '第一章',
        url: 'https://s.example/1',
        ord: 0,
        info: '章节字数：2400字　更新时间：2022-12-05',
      ),
    ], 'b1', sourceUrl: 'https://s.example');
    final again = await chapters.getToc('b1');
    expect(again, hasLength(1));
    expect(again.first.info, contains('2400'));
  });
}
