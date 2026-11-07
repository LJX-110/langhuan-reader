import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/features/backup/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<Database> openDb() async {
    // singleInstance: false → 每次打开都是独立的内存库，避免源/目标共用。
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ReaderDatabase.createSchema(db);
    return db;
  }

  Future<BackupService> serviceFor(Database db) async => BackupService(
    db: ReaderDatabase.withDatabase(db),
    prefs: SharedPreferences.getInstance(),
  );

  test('导出后可预览并恢复到空库', () async {
    SharedPreferences.setMockInitialValues({'theme_index': 3});
    final source = await openDb();
    await source.insert('books', {
      'id': 'b1',
      'name': '书一',
      'author': '作者',
      'chapter_index': 3,
      'page_index': 1,
      'reading_chapter': '第三章',
      'on_shelf': 1,
      'sort_time': 100,
    });
    await source.insert('bookmarks', {
      'id': 'm1',
      'book_id': 'b1',
      'chapter_index': 3,
      'page_index': 1,
      'chapter_name': '第三章',
      'excerpt': '摘录',
      'created_at': 100,
    });
    await source.insert('reading_history', {
      'book_id': 'b1',
      'chapter_index': 3,
      'page_index': 1,
      'chapter_name': '第三章',
      'read_at': 100,
    });
    await source.insert('tags', {'id': 't1', 'name': '玄幻', 'created_at': 100});
    await source.insert('book_tags', {'book_id': 'b1', 'tag_id': 't1'});
    await source.insert('replace_rules', {
      'id': 'r1',
      'name': '去广告',
      'pattern': '广告',
      'replacement': '',
      'is_regex': 0,
      'scope_content': 1,
      'scope_title': 0,
      'enabled': 1,
      'order_index': 0,
    });

    final bytes = await (await serviceFor(source)).exportBytes();
    final preview = await (await serviceFor(source)).preview(bytes);
    expect(preview.books, 1);
    expect(preview.bookmarks, 1);
    expect(preview.history, 1);
    expect(preview.tags, 1);
    expect(preview.replaceRules, 1);
    expect(preview.createdAt, greaterThan(0));

    final target = await openDb();
    final result = await (await serviceFor(target)).apply(bytes);
    expect(result.insertedBooks, 1);
    expect(result.bookmarks, 1);
    expect(result.history, 1);
    expect(result.tags, 1);
    expect(result.replaceRules, 1);

    final books = await target.query('books');
    expect(books.single['name'], '书一');
    expect(books.single['chapter_index'], 3);
    expect((await target.query('bookmarks')).length, 1);
    expect((await target.query('reading_history')).length, 1);
    expect((await target.query('tags')).single['name'], '玄幻');
    expect((await target.query('book_tags')).length, 1);
    expect((await target.query('replace_rules')).single['pattern'], '广告');
  });

  test('合并语义：本地进度与较新记录不被覆盖', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = await openDb();
    await source.insert('books', {
      'id': 'b1',
      'name': '书名',
      'chapter_index': 2,
      'page_index': 0,
      'reading_chapter': '第二章',
      'sort_time': 100,
    });
    await source.insert('bookmarks', {
      'id': 'm1',
      'book_id': 'b1',
      'excerpt': '旧摘录',
      'created_at': 100,
    });
    await source.insert('reading_history', {
      'book_id': 'b1',
      'chapter_index': 2,
      'read_at': 1000,
    });
    final bytes = await (await serviceFor(source)).exportBytes();

    final target = await openDb();
    await target.insert('books', {
      'id': 'b1',
      'name': '本地书名',
      'chapter_index': 10,
      'reading_chapter': '第十章',
      'sort_time': 200,
    });
    await target.insert('bookmarks', {
      'id': 'm1',
      'book_id': 'b1',
      'excerpt': '新摘录',
      'created_at': 200,
    });
    await target.insert('reading_history', {
      'book_id': 'b1',
      'chapter_index': 10,
      'read_at': 2000,
    });

    final result = await (await serviceFor(target)).apply(bytes);
    expect(result.insertedBooks, 0);
    expect(result.keptBooks, 1);

    final book = (await target.query('books')).single;
    expect(book['chapter_index'], 10);
    expect(book['name'], '本地书名');

    final bookmark = (await target.query('bookmarks')).single;
    expect(bookmark['excerpt'], '新摘录');

    final history = (await target.query('reading_history')).single;
    expect(history['chapter_index'], 10);
    expect(history['read_at'], 2000);
  });

  test('拒绝非本应用或字段不全的备份', () async {
    final service = await serviceFor(await openDb());
    Future<void> expectRejected(Object payload) async {
      await expectLater(
        service.preview(Uint8List.fromList(utf8.encode(jsonEncode(payload)))),
        throwsA(isA<BackupFormatException>()),
      );
    }

    await expectRejected({'hello': 'world'});
    await expectRejected({
      'format': backupFormat,
      'version': 2,
      'createdAt': 1,
      'books': [],
    });
    await expectRejected({
      'format': backupFormat,
      'version': 1,
      'createdAt': 1,
      'books': [
        {'name': '缺少 id'},
      ],
    });
  });
}
