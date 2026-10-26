import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/reader/model/toc_service.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/search_book.dart';

/// Volume headers must survive the engine and end up as grouping metadata on
/// the following chapters — never as readable chapters of their own.
void main() {
  group('engine TOC', () {
    late HttpServer server;
    late String base;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        final response = request.response
          ..headers.contentType = ContentType.html
          ..write(_tocHtml);
        await response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('keeps volume rows without a chapter url', () async {
      final payload = jsonEncode({
        'bookSourceUrl': base,
        'bookSourceName': '分卷测试源',
        'ruleToc': {
          'chapterList': '.catalog li',
          'chapterName': 'text',
          'chapterUrl': 'a@href',
          'isVolume': 'span@text',
        },
      });
      final source = SourceImporter.parseJson(payload).sources.single;

      final chapters = await BookSourceEngine().toc(source, '$base/toc');

      expect(chapters.map((c) => c.name).toList(), [
        '第一卷 少年游',
        '第一章 初入江湖',
        '第二章 山雨欲来',
        '第二卷 风起',
        '第三章 故人来',
      ]);
      expect(chapters[0].isVolume, isTrue);
      expect(chapters[0].url, isEmpty);
      expect(chapters[1].isVolume, isFalse);
      expect(chapters[1].url, '$base/1');
      expect(chapters[3].isVolume, isTrue);
    });
  });

  group('TocService.mapChapters', () {
    final book = Book(id: 'b1');

    test('attaches volumes, drops volume rows and url-less chapters', () {
      final entries = TocService.mapChapters(book, [
        SourceChapter(
          name: '- 第一卷 少年游 -',
          url: '',
          isVolume: true,
          index: 0,
        ),
        SourceChapter(
          name: '第一章 初入江湖',
          url: 'https://ex.com/1',
          index: 1,
        ),
        SourceChapter(
          name: '第二章',
          url: 'https://ex.com/2',
          index: 2,
        ),
        SourceChapter(name: '没有链接的章', url: '', index: 3),
        SourceChapter(
          name: '第二卷 风起',
          url: '',
          isVolume: true,
          index: 4,
        ),
        SourceChapter(
          name: '第三章',
          url: 'https://ex.com/3',
          index: 5,
        ),
      ]);

      expect(entries, hasLength(3));
      expect(entries.map((e) => e.ord).toList(), [0, 1, 2]);
      expect(entries[0].title, '第一章 初入江湖');
      expect(entries[0].volumeTitle, '第一卷 少年游');
      expect(entries[0].volumeOrd, 0);
      expect(entries[1].volumeTitle, '第一卷 少年游');
      expect(entries[2].volumeTitle, '第二卷 风起');
      expect(entries[2].volumeOrd, 1);
      expect(entries[2].url, 'https://ex.com/3');
    });

    test('sources without volumes keep empty grouping values', () {
      final entries = TocService.mapChapters(book, [
        SourceChapter(name: '第一章', url: 'https://ex.com/1', index: 0),
        SourceChapter(name: '第二章', url: 'https://ex.com/2', index: 1),
      ]);

      expect(entries, hasLength(2));
      expect(entries.every((e) => e.volumeTitle.isEmpty), isTrue);
      expect(entries.every((e) => e.volumeOrd == -1), isTrue);
    });
  });
}

const String _tocHtml = '''
<html><body>
<ul class="catalog">
  <li class="vol"><span>第一卷 少年游</span></li>
  <li><a href="/1">第一章 初入江湖</a></li>
  <li><a href="/2">第二章 山雨欲来</a></li>
  <li class="vol"><span>第二卷 风起</span></li>
  <li><a href="/3">第三章 故人来</a></li>
</ul>
</body></html>
''';
