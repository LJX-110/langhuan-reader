import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/legacy_schema_mapping.dart';
import 'package:langhuan/features/sources/util/book_id.dart';

void main() {
  group('LegacySchemaMapping', () {
    test('maps old books columns to the current schema', () {
      final mapped = LegacySchemaMapping.book({
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
      });

      expect(mapped, isNotNull);
      expect(mapped!['id'], 'b1');
      expect(mapped['name'], '书一');
      expect(mapped['cover_url'], 'https://a.com/cover.jpg');
      expect(mapped['description'], '简介');
      expect(mapped['chapter_index'], 2);
      expect(mapped['page_index'], 3);
      expect(mapped['scroll_offset'], 1.5);
      expect(mapped['latest_chapter'], '第十章');
      expect(mapped['sort_time'], 111);
      expect(mapped['has_update'], 0);
    });

    test('book without an id is rejected', () {
      expect(LegacySchemaMapping.book({'name': '无 id'}), isNull);
    });

    test('maps old chapter columns and normalises the order', () {
      final mapped = LegacySchemaMapping.chapter({
        'id': 1,
        'name': '第一章',
        'content': '正文',
        'book_id': 'b1',
        'hasContent': 1,
        'url': 'https://a.com/ch/1',
        'pages_json': '[{"old":true}]',
        'layout_fp': 'old-fp',
        'pages_cached_at': 123,
      }, ord: 4);

      expect(mapped, isNotNull);
      expect(mapped!['id'], makeChapterId('b1', 'https://a.com/ch/1'));
      expect(mapped['book_id'], 'b1');
      expect(mapped['title'], '第一章');
      expect(mapped['body'], '正文');
      expect(mapped['ord'], 4);
      expect(mapped['has_body'], 1);
      expect(mapped['content_len'], 2);
      expect(mapped['pages_json'], isNull);
      expect(mapped['layout_fp'], isNull);
      expect(mapped['pages_cached_at'], 0);
    });

    test('chapter without a book id is rejected', () {
      expect(
        LegacySchemaMapping.chapter({'name': '第一章', 'content': '正文'}, ord: 0),
        isNull,
      );
    });

    test(
      'maps legacy source columns and keeps missing fields disabled-safe',
      () {
        final mapped = LegacySchemaMapping.source({
          'book_source_url': 's1',
          'book_source_name': '源一',
          'custom_order': 7,
          'weight': 3,
        });

        expect(mapped, isNotNull);
        expect(mapped!['book_source_url'], 's1');
        expect(mapped['book_source_name'], '源一');
        expect(mapped['enabled'], 1);
        expect(mapped['custom_order'], 7);
        expect(mapped['weight'], 3);
        expect(mapped['last_update_time'], 0);
      },
    );

    test('source without a url is rejected', () {
      expect(LegacySchemaMapping.source({'book_source_name': '无地址'}), isNull);
    });

    test('maps old bookmark and history names', () {
      final bookmark = LegacySchemaMapping.bookmark({
        'id': 'm1',
        'bookId': 'b1',
        'chapterIndex': 2,
        'pageIndex': 3,
        'chapterName': '第二章',
        'text': '摘录',
        'createTime': 99,
      });
      expect(bookmark, isNotNull);
      expect(bookmark!['id'], 'm1');
      expect(bookmark['book_id'], 'b1');
      expect(bookmark['chapter_index'], 2);
      expect(bookmark['page_index'], 3);
      expect(bookmark['chapter_name'], '第二章');
      expect(bookmark['excerpt'], '摘录');
      expect(bookmark['created_at'], 99);

      final history = LegacySchemaMapping.readingHistory({
        'bookId': 'b1',
        'chapterIndex': 4,
        'pageIndex': 5,
        'chapterName': '第四章',
        'time': 88,
      });
      expect(history, isNotNull);
      expect(history!['book_id'], 'b1');
      expect(history['chapter_index'], 4);
      expect(history['page_index'], 5);
      expect(history['chapter_name'], '第四章');
      expect(history['read_at'], 88);
    });
  });
}
