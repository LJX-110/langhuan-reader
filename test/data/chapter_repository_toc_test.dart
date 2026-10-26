import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `syncToc` keeps body caches while renumbering a shifted TOC, and the
/// volume grouping columns survive a round trip through the DB.
void main() {
  late Database db;
  late ChapterRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ReaderDatabase.createSchema(db);
    await db.insert('books', {'id': 'b1', 'name': '测试书'});
    repository = ChapterRepository(db: ReaderDatabase.withDatabase(db));
  });

  tearDown(() => db.close());

  ChapterTocEntry entry(
    String id,
    String title, {
    int ord = 0,
    String volumeTitle = '',
    int volumeOrd = -1,
  }) => ChapterTocEntry(
    id: id,
    title: title,
    url: 'https://ex.com/$id',
    ord: ord,
    volumeTitle: volumeTitle,
    volumeOrd: volumeOrd,
  );

  test('volume fields survive a sync + read round trip', () async {
    await repository.syncToc(
      [
        entry('c1', '第一章', ord: 0, volumeTitle: '第一卷', volumeOrd: 0),
        entry('c2', '第二章', ord: 1, volumeTitle: '第一卷', volumeOrd: 0),
        entry('c3', '第三章', ord: 2, volumeTitle: '第二卷', volumeOrd: 1),
        entry('c4', '第四章', ord: 3),
      ],
      'b1',
      sourceUrl: 'https://ex.com',
    );

    final toc = await repository.getToc('b1');
    expect(toc, hasLength(4));
    expect(toc[0].volumeTitle, '第一卷');
    expect(toc[0].volumeOrd, 0);
    expect(toc[1].volumeTitle, '第一卷');
    expect(toc[2].volumeTitle, '第二卷');
    expect(toc[3].volumeTitle, '');
    expect(toc[3].volumeOrd, -1);
  });

  test('inserting a chapter at the front renumbers without collisions', () async {
    await repository.syncToc(
      [
        entry('c1', '第一章', ord: 0),
        entry('c2', '第二章', ord: 1),
        entry('c3', '第三章', ord: 2),
      ],
      'b1',
      sourceUrl: 'https://ex.com',
    );
    await db.update(
      'chapters',
      {'body': '第二章正文', 'has_body': 1, 'content_len': 5},
      where: 'id = ?',
      whereArgs: ['c2'],
    );

    // New chapter inserted at the front: every survivor's ord shifts by one.
    await repository.syncToc(
      [
        entry('c0', '楔子', ord: 0),
        entry('c1', '第一章', ord: 1),
        entry('c2', '第二章', ord: 2),
        entry('c3', '第三章', ord: 3),
      ],
      'b1',
      sourceUrl: 'https://ex.com',
    );

    final toc = await repository.getToc('b1');
    expect(toc.map((e) => e.id).toList(), ['c0', 'c1', 'c2', 'c3']);
    expect(toc.map((e) => e.ord).toList(), [0, 1, 2, 3]);

    final kept = (await db.query(
      'chapters',
      where: 'id = ?',
      whereArgs: ['c2'],
    )).single;
    expect(kept['body'], '第二章正文');
    expect(kept['has_body'], 1);
  });

  test('removing a chapter deletes only its row and its cache', () async {
    await repository.syncToc(
      [
        entry('c1', '第一章', ord: 0),
        entry('c2', '第二章', ord: 1),
        entry('c3', '第三章', ord: 2),
      ],
      'b1',
      sourceUrl: 'https://ex.com',
    );
    await db.update(
      'chapters',
      {'body': '第一章正文', 'has_body': 1, 'content_len': 5},
      where: 'id = ?',
      whereArgs: ['c1'],
    );

    await repository.syncToc(
      [entry('c1', '第一章', ord: 0), entry('c3', '第三章', ord: 1)],
      'b1',
      sourceUrl: 'https://ex.com',
    );

    final toc = await repository.getToc('b1');
    expect(toc.map((e) => e.id).toList(), ['c1', 'c3']);
    expect(toc.map((e) => e.ord).toList(), [0, 1]);
    final kept = (await db.query(
      'chapters',
      where: 'id = ?',
      whereArgs: ['c1'],
    )).single;
    expect(kept['body'], '第一章正文');
  });

  test('title updates reuse the cached body for the same id', () async {
    await repository.syncToc(
      [entry('c1', '第一章', ord: 0)],
      'b1',
      sourceUrl: 'https://ex.com',
    );
    await db.update(
      'chapters',
      {'body': '正文', 'has_body': 1, 'content_len': 2},
      where: 'id = ?',
      whereArgs: ['c1'],
    );

    await repository.syncToc(
      [entry('c1', '第一章 初入江湖', ord: 0, volumeTitle: '第一卷', volumeOrd: 0)],
      'b1',
      sourceUrl: 'https://ex.com',
    );

    final row = (await db.query(
      'chapters',
      where: 'id = ?',
      whereArgs: ['c1'],
    )).single;
    expect(row['title'], '第一章 初入江湖');
    expect(row['body'], '正文');
    expect(row['volume_title'], '第一卷');
    expect(row['volume_ord'], 0);
  });
}
