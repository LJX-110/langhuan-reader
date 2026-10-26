import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

BookSource _source(
  String url, {
  String name = '仓库源',
  String bookList = '.book',
  String searchUrl = 'https://example.com/search',
  bool enabled = true,
  int customOrder = 0,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    enabled: enabled,
    customOrder: customOrder,
    searchUrl: searchUrl,
    ruleSearch: SearchRule(bookList: bookList),
  );
}

Future<int> _count(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sources');
  return (rows.first['c'] as int?) ?? 0;
}

void main() {
  late Database db;
  late SourceRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ReaderDatabase.createSchema(db);
    repository = SourceRepository(db: ReaderDatabase.withDatabase(db));
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'default import inserts new rows and leaves existing rules untouched',
    () async {
      await repository.upsert(
        _source(
          'https://existing.example',
          name: '本地名',
          bookList: '.local',
          searchUrl: 'https://local.example/search',
          enabled: false,
          customOrder: 7,
        ),
      );

      final incoming = [
        for (var i = 0; i < 80; i++) _source('https://new$i.example'),
        _source(
          'https://existing.example',
          name: '仓库名',
          bookList: '.remote',
          searchUrl: 'https://remote.example/search',
        ),
      ];
      final stats = await repository.upsertAllWithStats(incoming);

      expect(stats.inserted, 80);
      expect(stats.updated, 0);
      expect(stats.preserved, 1);
      expect(await _count(db), 81);

      final row = (await db.query(
        'sources',
        where: 'book_source_url = ?',
        whereArgs: ['https://existing.example'],
      )).single;
      expect(row['book_source_name'], '本地名');
      expect(row['search_url'], 'https://local.example/search');
      expect(row['enabled'], 0);
      expect(row['custom_order'], 7);
    },
  );

  test('explicit overwrite updates rules but preserves local state', () async {
    await repository.upsert(
      _source(
        'https://existing.example',
        name: '本地名',
        bookList: '.local',
        enabled: false,
        customOrder: 7,
      ),
    );

    final stats = await repository.upsertAllWithStats([
      _source('https://existing.example', name: '仓库名', bookList: '.remote'),
    ], overwriteExistingRules: true);

    expect(stats.updated, 1);
    expect(stats.preserved, 0);

    final row = (await db.query(
      'sources',
      where: 'book_source_url = ?',
      whereArgs: ['https://existing.example'],
    )).single;
    expect(row['book_source_name'], '仓库名');
    expect(row['enabled'], 0);
    expect(row['custom_order'], 7);
    final saved = await repository.getByUrl('https://existing.example');
    expect(saved?.ruleSearch.bookList, '.remote');
  });

  test('a failure in a later chunk rolls back every earlier insert', () async {
    await db.execute('''
CREATE TRIGGER fail_source_import
BEFORE INSERT ON sources
WHEN NEW.book_source_url = 'https://fail.example'
BEGIN
  SELECT RAISE(ABORT, 'forced import failure');
END
''');

    final incoming = [
      for (var i = 0; i < 85; i++) _source('https://new$i.example'),
      _source('https://fail.example'),
    ];

    await expectLater(
      repository.upsertAllWithStats(incoming),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _count(db), 0);
  });

  test('overwrite transaction rolls back when a later row fails', () async {
    await db.execute('''
CREATE TRIGGER fail_source_overwrite
BEFORE INSERT ON sources
WHEN NEW.book_source_url = 'https://fail.example'
BEGIN
  SELECT RAISE(ABORT, 'forced overwrite failure');
END
''');

    final incoming = [
      for (var i = 0; i < 85; i++) _source('https://new$i.example'),
      _source('https://fail.example'),
    ];

    await expectLater(
      repository.overwriteAllWithRollback(incoming),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _count(db), 0);
  });
}
