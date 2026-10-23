import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/legacy_database_migrator.dart';
import 'package:path/path.dart' as p;

String _path(String name) => p.join('root', name);

class _FakeBackend implements LegacyMigrationBackend {
  _FakeBackend();

  final Set<String> files = {};
  final Map<String, Map<String, List<String>>> schema = {};
  final Map<String, Map<String, List<Map<String, Object?>>>> data = {};
  final List<String> deleted = [];
  final List<String> renameLog = [];
  final List<String> insertLog = [];
  final Map<String, List<Map<String, Object?>>> inserted = {};

  bool failInsert = false;

  void addDatabase(
    String name, {
    required Map<String, List<String>> columns,
    Map<String, List<Map<String, Object?>>>? rows,
  }) {
    final path = _path(name);
    files.add(path);
    schema[path] = columns;
    data[path] = rows ?? {};
  }

  @override
  Future<bool> exists(String path) async => files.contains(path);

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
    schema.remove(path);
    data.remove(path);
  }

  @override
  Future<void> rename(String from, String to) async {
    renameLog.add('$from -> $to');
    files.remove(from);
    files.add(to);
    final s = schema.remove(from);
    final d = data.remove(from);
    if (s != null) schema[to] = s;
    if (d != null) data[to] = d;
  }

  @override
  Future<void> createReaderDatabase(String path) async {
    files.add(path);
    schema[path] = {
      'books': ['id', 'name', 'author', 'chapter_index', 'page_index'],
      'sources': ['book_source_url', 'book_source_name', 'raw_json'],
      'chapters': ['id', 'book_id', 'title', 'body'],
      'bookmarks': ['id', 'book_id', 'chapter_index'],
      'reading_history': ['book_id', 'chapter_index'],
    };
    data[path] = {};
  }

  @override
  Future<List<String>> tables(String path) async =>
      (schema[path] ?? const {}).keys.toList();

  @override
  Future<List<String>> columns(String path, String table) async =>
      (schema[path] ?? const {})[table] ?? const [];

  @override
  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns,
  ) async {
    final all = (data[path] ?? const {})[table] ?? const [];
    return all
        .map((row) => {for (final c in columns) c: row[c]})
        .toList(growable: false);
  }

  @override
  Future<void> insertIgnore(
    String path,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (failInsert) throw StateError('insert failed');
    insertLog.add(table);
    inserted.putIfAbsent(table, () => []).addAll(rows);
  }

  @override
  Future<void> closeAll() async {}
}

void main() {
  group('LegacyDatabaseMigrator', () {
    test('no-op when reader.db already exists', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'reader.db',
          columns: {
            'books': ['id', 'name'],
          },
        )
        ..addDatabase(
          'books.db',
          columns: {
            'books': ['id', 'name'],
          },
        );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.targetExists);
      expect(backend.deleted, isEmpty);
      expect(backend.renameLog, isEmpty);
      expect(backend.insertLog, isEmpty);
    });

    test('does nothing when there is no legacy file', () async {
      final backend = _FakeBackend();

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.noLegacy);
      expect(backend.files, isEmpty);
      expect(backend.deleted, isEmpty);
    });

    test('copies the shared columns and keeps legacy files', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'books.db',
          columns: {
            'books': ['id', 'name', 'legacy_only'],
            'ignored_table': ['id'],
          },
          rows: {
            'books': [
              {'id': 'b1', 'name': '书一', 'legacy_only': 'x'},
              {'id': 'b2', 'name': '书二', 'legacy_only': 'y'},
            ],
          },
        )
        ..addDatabase(
          'chapters.db',
          columns: {
            'chapters': ['id', 'book_id', 'body', 'extra'],
          },
          rows: {
            'chapters': [
              {'id': 'c1', 'book_id': 'b1', 'body': '正文', 'extra': 'z'},
            ],
          },
        );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.migrated);
      expect(result.copiedRows, 3);
      expect(backend.renameLog, hasLength(1));
      expect(backend.renameLog.single, contains('reader.db.migrating'));
      expect(backend.files, contains(_path('reader.db')));
      expect(backend.files, isNot(contains(_path('reader.db.migrating'))));
      expect(backend.files, contains(_path('books.db')));
      expect(backend.files, contains(_path('chapters.db')));
      expect(backend.insertLog, ['books', 'chapters']);
      expect(backend.inserted['books']!.first, {'id': 'b1', 'name': '书一'});
      expect(backend.inserted['chapters']!.single, {
        'id': 'c1',
        'book_id': 'b1',
        'body': '正文',
      });
      expect(backend.inserted.containsKey('ignored_table'), isFalse);
    });

    test('failed import removes only its scratch file', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'books.db',
          columns: {
            'books': ['id', 'name'],
          },
          rows: {
            'books': [
              {'id': 'b1', 'name': '书一'},
            ],
          },
        )
        ..failInsert = true;

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.failed);
      expect(result.error, isNotNull);
      expect(backend.files, isNot(contains(_path('reader.db'))));
      expect(backend.files, isNot(contains(_path('reader.db.migrating'))));
      expect(backend.files, contains(_path('books.db')));
      expect(backend.renameLog, isEmpty);
    });
  });
}
