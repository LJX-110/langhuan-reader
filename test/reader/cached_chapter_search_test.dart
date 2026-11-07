import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/features/reader/model/cached_chapter_search.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late ChapterRepository repo;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ReaderDatabase.createSchema(db);
    repo = ChapterRepository(db: ReaderDatabase.withDatabase(db));
  });

  Future<void> chapter(
    String id, {
    required int ord,
    required String title,
    required String body,
    int hasBody = 1,
  }) => db.insert('chapters', {
    'id': id,
    'book_id': 'b1',
    'title': title,
    'url': 'https://ex.com/$id',
    'ord': ord,
    'body': body,
    'has_body': hasBody,
  });

  test('只返回已缓存且正文命中的章节，ord 即章节序号', () async {
    await chapter('c1', ord: 0, title: '第一章', body: '萧炎醒来。');
    await chapter('c2', ord: 1, title: '第二章', body: '正文没有关键词。');
    await chapter('c3', ord: 2, title: '第三章', body: '萧炎又出现。');
    await chapter('c4', ord: 3, title: '第四章', body: '萧炎未缓存。', hasBody: 0);

    final rows = await repo.searchCachedBodies('b1', '萧炎');
    expect(rows.map((r) => r.ord).toList(), [0, 2]);
    expect(rows.first.title, '第一章');
  });

  test('LIKE 通配符按字面处理', () async {
    await chapter('c1', ord: 0, title: '第一章', body: '进度 100% 完成');
    final rows = await repo.searchCachedBodies('b1', '100%');
    expect(rows, hasLength(1));
  });

  test('跨章搜索生成上下文摘要与命中次数', () async {
    await chapter(
      'c1',
      ord: 0,
      title: '第一章',
      body: '<p>萧炎睁开眼，发现自己回到了少年时代。萧炎握紧拳头。</p>',
    );
    await chapter('c2', ord: 1, title: '第二章', body: '<p>没有关键词。</p>');

    final hits = await CachedChapterSearch.search(
      bookId: 'b1',
      query: '萧炎',
      repo: repo,
    );
    expect(hits, hasLength(1));
    expect(hits.single.chapterIndex, 0);
    expect(hits.single.title, '第一章');
    expect(hits.single.occurrences, 2);
    expect(hits.single.snippet, contains('萧炎'));
  });

  test('空关键词与空书 id 不发查询', () async {
    expect(await repo.searchCachedBodies('', '萧炎'), isEmpty);
    expect(await repo.searchCachedBodies('b1', ''), isEmpty);
  });
}
