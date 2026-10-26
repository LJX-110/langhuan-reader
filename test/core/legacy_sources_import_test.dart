import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Legacy `sources.db` import must be idempotent and all-or-nothing:
/// a failure may not leave half a source list, and a retry must complete
/// rows an interrupted run had already written.
void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ReaderDatabase.createSchema(db);
  });

  tearDown(() => db.close());

  Map<String, Object?> legacyRow(String url, {String name = '旧源'}) => {
    'book_source_url': url,
    'book_source_name': name,
    'search_url': 'https://old.example/search',
    'raw_json': '{"bookSourceUrl":"$url"}',
  };

  Future<int> count() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sources');
    return (rows.first['c'] as int?) ?? 0;
  }

  test('imports usable rows and counts unusable ones', () async {
    final stats = await ReaderDatabase.insertLegacySources(db, [
      legacyRow('https://a.example'),
      {'book_source_name': '没有地址'},
      legacyRow('https://b.example'),
    ]);

    expect(stats.inserted, 2);
    expect(stats.invalid, 1);
    expect(await count(), 2);
  });

  test('existing rows keep their local state', () async {
    await db.insert('sources', {
      'book_source_url': 'https://a.example',
      'book_source_name': '本地改名',
      'enabled': 0,
      'custom_order': 9,
    });

    final stats = await ReaderDatabase.insertLegacySources(db, [
      legacyRow('https://a.example', name: '旧名'),
      legacyRow('https://b.example'),
    ]);

    expect(stats.inserted, 1);
    final row = (await db.query(
      'sources',
      where: 'book_source_url = ?',
      whereArgs: ['https://a.example'],
    )).single;
    expect(row['book_source_name'], '本地改名');
    expect(row['enabled'], 0);
    expect(row['custom_order'], 9);
  });

  test('a failed batch leaves no partial rows', () async {
    await db.execute('''
CREATE TRIGGER fail_legacy_import
BEFORE INSERT ON sources
WHEN NEW.book_source_url = 'https://fail.example'
BEGIN
  SELECT RAISE(ABORT, 'forced legacy import failure');
END
''');

    await expectLater(
      ReaderDatabase.insertLegacySources(db, [
        legacyRow('https://ok.example'),
        legacyRow('https://fail.example'),
      ]),
      throwsA(isA<DatabaseException>()),
    );

    expect(await count(), 0);
  });

  test('a retry completes rows from an interrupted earlier run', () async {
    // The old importer could leave one row behind without a marker. The
    // retry must import the remaining rows instead of stopping at "not 0".
    await db.insert('sources', {'book_source_url': 'https://a.example'});

    final stats = await ReaderDatabase.insertLegacySources(db, [
      legacyRow('https://a.example'),
      legacyRow('https://b.example'),
      legacyRow('https://c.example'),
    ]);

    expect(stats.inserted, 2);
    expect(await count(), 3);
  });
}
