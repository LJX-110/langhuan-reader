import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/legacy_database_migrator.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
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
  final Map<String, String> texts = {};

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
    texts.remove(path);
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
    final t = texts.remove(from);
    if (t != null) texts[to] = t;
  }

  @override
  Future<void> createReaderDatabase(String path) async {
    files.add(path);
    schema[path] = {
      'books': [
        'id',
        'name',
        'author',
        'cover_url',
        'category',
        'description',
        'source_url',
        'book_url',
        'origin_name',
        'toc_url',
        'chapter_index',
        'page_index',
        'scroll_offset',
        'reading_chapter',
        'latest_chapter',
        'sort_time',
        'has_update',
        'updated_at',
      ],
      'chapters': [
        'id',
        'book_id',
        'title',
        'url',
        'source_url',
        'ord',
        'body',
        'has_body',
        'content_len',
        'pages_json',
        'layout_fp',
        'pages_cached_at',
      ],
      'sources': [
        'book_source_url',
        'book_source_name',
        'book_source_group',
        'book_source_type',
        'enabled',
        'custom_order',
        'weight',
        'search_url',
        'explore_url',
        'header',
        'raw_json',
        'last_update_time',
        'respond_time',
        'last_check_time',
      ],
      'bookmarks': [
        'id',
        'book_id',
        'chapter_index',
        'page_index',
        'chapter_name',
        'excerpt',
        'created_at',
      ],
      'reading_history': [
        'book_id',
        'chapter_index',
        'page_index',
        'chapter_name',
        'read_at',
      ],
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
  Future<int> count(String path, String table) async =>
      (data[path]?[table] ?? const []).length;

  @override
  Future<List<Map<String, Object?>>> rows(
    String path,
    String table,
    List<String> columns, {
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    final all = data[path]?[table] ?? const [];
    final start = offset ?? 0;
    final slice = limit == null ? all.skip(start) : all.skip(start).take(limit);
    return slice
        .map((row) => {for (final c in columns) c: row[c]})
        .toList(growable: false);
  }

  @override
  Future<int> insertIgnore(
    String path,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (failInsert) throw StateError('insert failed');
    insertLog.add(table);
    final existing = data[path]!.putIfAbsent(table, () => []);
    var count = 0;
    for (final row in rows) {
      if (_isDuplicate(table, existing, row)) continue;
      final copy = Map<String, Object?>.of(row);
      existing.add(copy);
      inserted.putIfAbsent(table, () => []).add(copy);
      count++;
    }
    return count;
  }

  bool _isDuplicate(
    String table,
    List<Map<String, Object?>> existing,
    Map<String, Object?> row,
  ) {
    switch (table) {
      case 'books':
        return existing.any((e) => e['id'] == row['id']);
      case 'sources':
        return existing.any(
          (e) => e['book_source_url'] == row['book_source_url'],
        );
      case 'chapters':
        return existing.any(
          (e) =>
              e['id'] == row['id'] ||
              (e['book_id'] == row['book_id'] && e['ord'] == row['ord']),
        );
      case 'bookmarks':
        return existing.any((e) => e['id'] == row['id']);
      case 'reading_history':
        return existing.any((e) => e['book_id'] == row['book_id']);
    }
    return false;
  }

  @override
  Future<void> writeText(String path, String text) async {
    files.add(path);
    texts[path] = text;
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
            'books': ['book_id', 'name'],
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

    test('maps the real legacy books / chapters / sources schema', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'books.db',
          columns: {
            'books': [
              'book_id',
              'name',
              'author',
              'img',
              'intro',
              'source_url',
              'book_url',
              'origin_name',
              'toc_url',
              'cur',
              'idx',
              'position',
              'reading_chapter',
              'newChapter',
              'sortTime',
              'utime',
            ],
          },
          rows: {
            'books': [
              {
                'book_id': 'b1',
                'name': '书一',
                'author': '作者',
                'img': 'https://a.com/cover.jpg',
                'intro': '简介',
                'source_url': 's1',
                'book_url': 'https://a.com/book/1',
                'origin_name': '源一',
                'toc_url': 'https://a.com/toc/1',
                'cur': 2,
                'idx': 3,
                'position': 1.5,
                'reading_chapter': '第二章',
                'newChapter': '第十章',
                'sortTime': 111,
                'utime': 222,
              },
            ],
          },
        )
        ..addDatabase(
          'chapters.db',
          columns: {
            'chapters': [
              'id',
              'chapter_id',
              'name',
              'content',
              'book_id',
              'hasContent',
              'url',
              'source_url',
              'idx',
              'book_key',
              'pages_json',
              'layout_fp',
              'pages_cached_at',
              'content_len',
            ],
          },
          rows: {
            'chapters': [
              {
                'id': 1,
                'chapter_id': 'c1',
                'name': '第一章',
                'content': '正文一',
                'book_id': 'b1',
                'hasContent': 1,
                'url': 'https://a.com/ch/1',
                'source_url': 's1',
                'idx': 0,
                'book_key': 'b1',
                'pages_json': '[{"old":true}]',
                'layout_fp': 'old-fp',
                'pages_cached_at': 123,
                'content_len': 3,
              },
              {
                'id': 2,
                'chapter_id': 'c2',
                'name': '第二章',
                'content': '正文二',
                'book_id': 'b1',
                'hasContent': 1,
                'url': 'https://a.com/ch/2',
                'source_url': 's1',
                'idx': 1,
                'book_key': 'b1',
                'pages_json': null,
                'layout_fp': null,
                'pages_cached_at': 0,
                'content_len': 3,
              },
            ],
          },
        )
        ..addDatabase(
          'sources.db',
          columns: {
            'sources': [
              'book_source_url',
              'book_source_name',
              'book_source_group',
              'book_source_type',
              'enabled',
              'custom_order',
              'weight',
              'search_url',
              'explore_url',
              'header',
              'raw_json',
              'last_update_time',
              'respond_time',
              'last_check_time',
            ],
          },
          rows: {
            'sources': [
              {
                'book_source_url': 's1',
                'book_source_name': '源一',
                'book_source_group': '分组',
                'book_source_type': 1,
                'custom_order': 7,
                'weight': 3,
                'search_url': '/search?key={{key}}',
                'header': '{"User-Agent":"x"}',
                'raw_json': '{}',
              },
            ],
          },
        );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.migrated);
      expect(result.copiedRows, 4);
      expect(result.skippedRows, 0);

      final book = backend.inserted['books']!.single;
      expect(book['id'], 'b1');
      expect(book['name'], '书一');
      expect(book['cover_url'], 'https://a.com/cover.jpg');
      expect(book['description'], '简介');
      expect(book['origin_name'], '源一');
      expect(book['chapter_index'], 2);
      expect(book['page_index'], 3);
      expect(book['scroll_offset'], 1.5);
      expect(book['latest_chapter'], '第十章');
      expect(book['sort_time'], 111);

      final chapters = backend.inserted['chapters']!;
      expect(chapters, hasLength(2));
      expect(chapters[0]['id'], makeChapterId('b1', 'https://a.com/ch/1'));
      expect(chapters[0]['title'], '第一章');
      expect(chapters[0]['body'], '正文一');
      expect(chapters[0]['ord'], 0);
      expect(chapters[0]['has_body'], 1);
      expect(chapters[0]['pages_json'], isNull);
      expect(chapters[0]['layout_fp'], isNull);
      expect(chapters[1]['ord'], 1);

      final source = backend.inserted['sources']!.single;
      expect(source['book_source_url'], 's1');
      expect(source['enabled'], 1);
      expect(source['custom_order'], 7);
      expect(source['weight'], 3);

      expect(backend.files, contains(_path('reader.db')));
      expect(backend.files, isNot(contains(_path('reader.db.migrating'))));
      expect(backend.files, contains(_path('books.db')));
      expect(backend.files, contains(_path('chapters.db')));
      expect(backend.files, contains(_path('sources.db')));
      expect(
        backend.files,
        isNot(contains(_path(LegacyDatabaseMigrator.pendingFileName))),
      );
    });

    test('invalid legacy chapter fails instead of being counted', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'chapters.db',
          columns: {
            'chapters': ['name', 'content', 'book_id'],
          },
          rows: {
            'chapters': [
              {'name': '第一章', 'content': '正文', 'book_id': ''},
            ],
          },
        );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.failed);
      expect(result.error, isA<LegacyMigrationException>());
      expect(backend.files, isNot(contains(_path('reader.db'))));
      expect(backend.files, contains(_path('chapters.db')));
      expect(
        backend.texts[_path(LegacyDatabaseMigrator.pendingFileName)],
        contains('no usable identity'),
      );
    });

    test(
      'duplicate legacy chapters are skipped but migration succeeds',
      () async {
        final backend = _FakeBackend()
          ..addDatabase(
            'chapters.db',
            columns: {
              'chapters': ['name', 'content', 'book_id', 'url', 'idx'],
            },
            rows: {
              'chapters': [
                {
                  'name': '第一章',
                  'content': '正文',
                  'book_id': 'b1',
                  'url': 'https://a.com/ch/1',
                  'idx': 0,
                },
                {
                  'name': '第一章重复',
                  'content': '正文2',
                  'book_id': 'b1',
                  'url': 'https://a.com/ch/1',
                  'idx': 1,
                },
              ],
            },
          );

        final result = await LegacyDatabaseMigrator(
          backend: backend,
        ).migrate('root');

        expect(result.status, LegacyMigrationStatus.migrated);
        expect(result.copiedRows, 1);
        expect(result.skippedRows, 1);
        expect(backend.inserted['chapters'], hasLength(1));
      },
    );

    test('pages through large legacy tables without dropping rows', () async {
      final rows = List.generate(205, (i) => {'book_id': 'b$i', 'name': '书$i'});
      final backend = _FakeBackend()
        ..addDatabase(
          'books.db',
          columns: {
            'books': ['book_id', 'name'],
          },
          rows: {'books': rows},
        );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.migrated);
      expect(result.copiedRows, 205);
      expect(backend.inserted['books'], hasLength(205));
    });

    test('failed import removes only its scratch file', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'books.db',
          columns: {
            'books': ['book_id', 'name'],
          },
          rows: {
            'books': [
              {'book_id': 'b1', 'name': '书一'},
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
      expect(
        backend.files,
        contains(_path(LegacyDatabaseMigrator.pendingFileName)),
      );
      expect(
        backend.texts[_path(LegacyDatabaseMigrator.pendingFileName)],
        contains('insert failed'),
      );
      expect(backend.renameLog, isEmpty);
    });

    test(
      'retry after failure merges into the newly created database',
      () async {
        final backend = _FakeBackend()
          ..addDatabase(
            'books.db',
            columns: {
              'books': ['book_id', 'name'],
            },
            rows: {
              'books': [
                {'book_id': 'b1', 'name': '书一'},
              ],
            },
          )
          ..failInsert = true;
        final migrator = LegacyDatabaseMigrator(backend: backend);

        final first = await migrator.migrate('root');
        expect(first.status, LegacyMigrationStatus.failed);

        // ReaderDatabase opens a fresh reader.db after the failed import.
        await backend.createReaderDatabase(_path('reader.db'));
        backend.failInsert = false;

        final second = await migrator.migrate('root');

        expect(second.status, LegacyMigrationStatus.merged);
        expect(second.copiedRows, 1);
        expect(backend.files, contains(_path('reader.db')));
        expect(
          backend.files,
          isNot(contains(_path(LegacyDatabaseMigrator.pendingFileName))),
        );
        expect(backend.inserted['books']!.single['id'], 'b1');
      },
    );

    test('stale marker is cleared when no legacy file remains', () async {
      final backend = _FakeBackend()
        ..addDatabase(
          'reader.db',
          columns: {
            'books': ['id', 'name'],
          },
        );
      await backend.writeText(
        _path(LegacyDatabaseMigrator.pendingFileName),
        'old failure',
      );

      final result = await LegacyDatabaseMigrator(
        backend: backend,
      ).migrate('root');

      expect(result.status, LegacyMigrationStatus.targetExists);
      expect(
        backend.files,
        isNot(contains(_path(LegacyDatabaseMigrator.pendingFileName))),
      );
      expect(backend.insertLog, isEmpty);
    });

    test(
      'successful import clears a marker left before reader.db existed',
      () async {
        final backend = _FakeBackend()
          ..addDatabase(
            'books.db',
            columns: {
              'books': ['book_id', 'name'],
            },
            rows: {
              'books': [
                {'book_id': 'b1', 'name': '书一'},
              ],
            },
          );
        await backend.writeText(
          _path(LegacyDatabaseMigrator.pendingFileName),
          'old failure',
        );

        final result = await LegacyDatabaseMigrator(
          backend: backend,
        ).migrate('root');

        expect(result.status, LegacyMigrationStatus.migrated);
        expect(
          backend.files,
          isNot(contains(_path(LegacyDatabaseMigrator.pendingFileName))),
        );
      },
    );
  });
}
