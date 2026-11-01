import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_node.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/repositories/reading_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// M6 治理：缓存只清正文、保留目录行；阅读记录可单条移除 / 清空。
void main() {
  setUpAll(sqfliteFfiInit);

  test('clearBodies 保留目录行，只清正文与分页', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);
    final readerDb = ReaderDatabase.withDatabase(db);
    final chapters = ChapterRepository(db: readerDb);
    await BookRepository(
      db: readerDb,
    ).upsert(Book(id: 'b1', name: '书一', sourceUrl: 'https://s.example'));

    await chapters.syncToc([
      ChapterTocEntry(
        id: 'c1',
        title: '第一章',
        url: 'https://s.example/1',
        ord: 0,
      ),
      ChapterTocEntry(
        id: 'c2',
        title: '第二章',
        url: 'https://s.example/2',
        ord: 1,
      ),
    ], 'b1', sourceUrl: 'https://s.example');
    await chapters.updateBodies([
      ChapterNode('正文一', 'c1'),
      ChapterNode('正文二', 'c2'),
    ]);
    await chapters.savePageLayout('c1', '[]', 'fp');

    var stats = await chapters.bodyStats('b1');
    expect(stats.total, 2);
    expect(stats.withBody, 2);
    expect(await chapters.bodyCacheBytes(), greaterThan(0));

    await chapters.clearBodies('b1');

    // 目录行保留（标题 / 进度 / 分卷信息不丢），正文与分页归零。
    final toc = await chapters.getToc('b1');
    expect(toc, hasLength(2));
    expect(toc[0].title, '第一章');
    stats = await chapters.bodyStats('b1');
    expect(stats.total, 2);
    expect(stats.withBody, 0);
    expect(await chapters.bodyCacheBytes(), 0);
    expect(await chapters.pageCacheBytes(), 0);
    expect(await chapters.getBody('c1'), '');
  });

  test('clearAllBodies 覆盖所有书且保留目录', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);
    final readerDb = ReaderDatabase.withDatabase(db);
    final chapters = ChapterRepository(db: readerDb);
    final books = BookRepository(db: readerDb);
    await books.upsert(Book(id: 'b1', name: '书一', sourceUrl: 'https://s.example'));
    await books.upsert(Book(id: 'b2', name: '书二', sourceUrl: 'https://s.example'));

    await chapters.syncToc([
      ChapterTocEntry(id: 'a1', title: '甲一', url: 'https://s.example/a1', ord: 0),
    ], 'b1', sourceUrl: 'https://s.example');
    await chapters.syncToc([
      ChapterTocEntry(id: 'd1', title: '乙一', url: 'https://s.example/d1', ord: 0),
    ], 'b2', sourceUrl: 'https://s.example');
    await chapters.updateBodies([
      ChapterNode('正文甲', 'a1'),
      ChapterNode('正文乙', 'd1'),
    ]);

    await chapters.clearAllBodies();

    expect((await chapters.bodyStats('b1')).withBody, 0);
    expect((await chapters.bodyStats('b2')).withBody, 0);
    expect(await chapters.getToc('b1'), hasLength(1));
    expect(await chapters.getToc('b2'), hasLength(1));
    expect(await chapters.bodyCacheBytes(), 0);
  });

  test('reading_history：remove 只移记录，clear 清空', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await ReaderDatabase.createSchema(db);
    final readerDb = ReaderDatabase.withDatabase(db);
    final books = BookRepository(db: readerDb);
    final history = ReadingHistoryRepository(db: readerDb);
    await books.upsert(Book(id: 'b1', name: '书一', sourceUrl: 'https://s.example'));
    await books.upsert(Book(id: 'b2', name: '书二', sourceUrl: 'https://s.example'));

    await history.touch(
      bookId: 'b1',
      chapterIndex: 3,
      pageIndex: 1,
      chapterName: '第三章',
    );
    await history.touch(
      bookId: 'b2',
      chapterIndex: 0,
      pageIndex: 0,
      chapterName: '第一章',
    );
    expect(await history.recent(), hasLength(2));

    // 移除一条：其它记录与 books 行（书架 / 进度）都保留。
    await history.remove('b1');
    final after = await history.recent();
    expect(after, hasLength(1));
    expect(after.single.bookId, 'b2');
    expect(await books.getById('b1'), isNotNull);

    await history.clear();
    expect(await history.recent(), isEmpty);
    // 清空记录不影响书籍行。
    expect(await books.getById('b2'), isNotNull);
  });
}
