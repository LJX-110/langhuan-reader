import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// v3 → v4 upgrade: `chapters` gains `volume_title` / `volume_ord`.
///
/// The migration is additive (`_ensureColumns`); books, chapter bodies and
/// reading progress must survive, and re-running `createSchema` on every open
/// must stay idempotent.
Future<void> _createV3Schema(Database db) async {
  await db.execute('''
CREATE TABLE books (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL DEFAULT ''
)''');
  await db.execute('''
CREATE TABLE chapters (
  id TEXT PRIMARY KEY NOT NULL,
  book_id TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL DEFAULT '',
  url TEXT NOT NULL DEFAULT '',
  source_url TEXT NOT NULL DEFAULT '',
  ord INTEGER NOT NULL DEFAULT 0,
  body TEXT NOT NULL DEFAULT '',
  has_body INTEGER NOT NULL DEFAULT 0,
  content_len INTEGER NOT NULL DEFAULT 0,
  pages_json TEXT,
  layout_fp TEXT,
  pages_cached_at INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute(
    'CREATE UNIQUE INDEX idx_chapters_book_ord ON chapters (book_id, ord)',
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('v3 → v4 adds volume columns and keeps every row', () async {
    final dir = await Directory.systemTemp.createTemp('langhuan-migration');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/reader.db';

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) => _createV3Schema(db),
        singleInstance: false,
      ),
    );
    await db.insert('books', {'id': 'b1', 'name': '旧书'});
    await db.insert('chapters', {
      'id': 'c1',
      'book_id': 'b1',
      'title': '第一章',
      'url': '/1',
      'ord': 0,
      'body': '第一章正文',
      'has_body': 1,
      'content_len': 5,
    });
    await db.insert('chapters', {
      'id': 'c2',
      'book_id': 'b1',
      'title': '第二章',
      'url': '/2',
      'ord': 1,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: ReaderDatabase.version,
        onCreate: (db, _) => ReaderDatabase.createSchema(db),
        onUpgrade: (db, _, _) => ReaderDatabase.createSchema(db),
        singleInstance: false,
      ),
    );
    // The production open path also runs createSchema once as a repair pass.
    await ReaderDatabase.createSchema(db);

    final columns = (await db.rawQuery('PRAGMA table_info(chapters)'))
        .map((r) => r['name']?.toString() ?? '')
        .toSet();
    expect(columns, containsAll(['volume_title', 'volume_ord']));

    final chapters = await db.query('chapters', orderBy: 'ord ASC');
    expect(chapters, hasLength(2));
    expect(chapters[0]['body'], '第一章正文');
    expect(chapters[0]['volume_title'], '');
    expect(chapters[0]['volume_ord'], -1);
    expect(await db.query('books'), hasLength(1));

    // Second open must be a no-op (idempotent repair).
    await db.close();
    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: ReaderDatabase.version,
        onCreate: (db, _) => ReaderDatabase.createSchema(db),
        onUpgrade: (db, _, _) => ReaderDatabase.createSchema(db),
        singleInstance: false,
      ),
    );
    await ReaderDatabase.createSchema(db);
    expect(await db.query('chapters'), hasLength(2));
    expect(
      (await db.rawQuery('PRAGMA table_info(chapters)'))
          .where((r) => r['name'] == 'volume_title'),
      hasLength(1),
    );
    await db.close();
  });
}
