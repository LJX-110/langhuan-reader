import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 批量移动分组只改写 book_source_group，其它行与字段保持原样。
void main() {
  late Database db;
  late SourceRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ReaderDatabase.createSchema(db);
    repository = SourceRepository(db: ReaderDatabase.withDatabase(db));
  });

  tearDown(() => db.close());

  BookSource source(String url, {String group = '', bool enabled = true}) =>
      BookSource(
        bookSourceUrl: url,
        bookSourceName: url,
        searchUrl: '/s?q={{key}}',
        enabled: enabled,
      )..bookSourceGroup = group;

  test('updates only the selected urls', () async {
    await repository.upsert(source('https://a.com', group: '旧组'));
    await repository.upsert(source('https://b.com'));
    await repository.upsert(
      source('https://c.com', group: '其它', enabled: false),
    );

    await repository.updateGroups(['https://a.com', 'https://b.com'], '新组');

    final rows = await db.query('sources', orderBy: 'book_source_url ASC');
    final byUrl = {
      for (final row in rows) row['book_source_url'] as String: row,
    };
    expect(byUrl['https://a.com']!['book_source_group'], '新组');
    expect(byUrl['https://b.com']!['book_source_group'], '新组');
    expect(byUrl['https://c.com']!['book_source_group'], '其它');
    // 启用状态与规则不受分组移动影响。
    expect(byUrl['https://c.com']!['enabled'], 0);
    expect(byUrl['https://a.com']!['search_url'], '/s?q={{key}}');
  });

  test('an empty group clears the grouping', () async {
    await repository.upsert(source('https://a.com', group: '旧组'));

    await repository.updateGroups(['https://a.com'], '');

    final row = (await db.query(
      'sources',
      where: 'book_source_url = ?',
      whereArgs: ['https://a.com'],
    )).single;
    expect(row['book_source_group'], '');
  });

  test('an empty url list is a no-op', () async {
    await repository.upsert(source('https://a.com', group: '旧组'));
    await repository.updateGroups(const [], '新组');
    final row = (await db.query(
      'sources',
      where: 'book_source_url = ?',
      whereArgs: ['https://a.com'],
    )).single;
    expect(row['book_source_group'], '旧组');
  });
}
