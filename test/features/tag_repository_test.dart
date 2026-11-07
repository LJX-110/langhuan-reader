import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/repositories/tag_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late TagRepository repo;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ReaderDatabase.createSchema(db);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.insert('books', {'id': 'b1', 'name': '书一'});
    await db.insert('books', {'id': 'b2', 'name': '书二'});
    repo = TagRepository(db: ReaderDatabase.withDatabase(db));
  });

  test('创建、授权、按标签查书、重命名与删除', () async {
    final t1 = (await repo.create('玄幻'))!;
    final t2 = (await repo.create('待读'))!;

    // 同名复用，不新建。
    final again = await repo.create('玄幻');
    expect(again!.id, t1.id);
    expect((await repo.all()).length, 2);

    await repo.setForBook('b1', [t1.id, t2.id]);
    await repo.setForBook('b2', [t1.id]);
    expect((await repo.forBook('b1')).length, 2);
    expect(await repo.bookIdsForTag(t1.id), {'b1', 'b2'});
    expect((await repo.counts())[t1.id], 2);

    // 重名拒绝。
    expect(await repo.rename(t2.id, '玄幻'), isFalse);
    expect(await repo.rename(t2.id, '待读中'), isTrue);

    await repo.delete(t1.id);
    expect((await repo.bookIdsForTag(t1.id)).isEmpty, isTrue);
    expect((await repo.forBook('b2')).isEmpty, isTrue);
  });

  test('空白或超长标签名不写入', () async {
    expect(await repo.create('   '), isNull);
    expect(await repo.create('x' * 25), isNull);
    expect((await repo.all()).isEmpty, isTrue);
  });
}
