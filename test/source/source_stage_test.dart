import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

/// Single-source stage tests: every stage must report pass/fail **and** the
/// rule field to blame, so the test sheet can point at the exact rule.
void main() {
  late HttpServer server;
  late String base;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      final response = request.response..headers.contentType = ContentType.html;
      switch (request.uri.path) {
        case '/search':
          response.write(_searchHtml);
        case '/book/1':
          response.write(_detailHtml);
        case '/toc':
          response.write(_tocHtml);
        case '/read/1':
          response.write(_contentHtml);
        case '/read/plain':
          response.write(_plainBodyHtml);
        default:
          response.statusCode = HttpStatus.notFound;
          response.write('<html><body>not found</body></html>');
      }
      await response.close();
    });
  });

  tearDown(() => server.close(force: true));

  BookSource source({
    String name = '.book-name',
    String chapterList = '.catalog li a',
    String content = '#content',
    String tocRule = '.toc-link@href',
  }) {
    final payload = jsonEncode({
      'bookSourceUrl': base,
      'bookSourceName': '阶段测试源',
      'searchUrl': '$base/search?q={{key}}',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text', 'bookUrl': 'a@href'},
      'ruleBookInfo': {
        'name': name,
        'tocUrl': tocRule,
      },
      'ruleToc': {
        'chapterList': chapterList,
        'chapterName': 'text',
        'chapterUrl': 'href',
      },
      'ruleContent': {'content': content},
    });
    return SourceImporter.parseJson(payload).sources.single;
  }

  final engine = BookSourceEngine();

  test('detail stage passes and carries the catalog url', () async {
    final result = await engine.testBookInfo(source(), '$base/book/1');

    expect(result.ok, isTrue);
    expect(result.stage, 'bookInfo');
    expect(result.sample, '斗破苍穹');
    expect(result.tocUrl, '$base/toc');
  });

  test('detail stage blames the name rule when it misses', () async {
    final result = await engine.testBookInfo(
      source(name: '.missing-name'),
      '$base/book/1',
    );

    expect(result.ok, isFalse);
    expect(result.field, 'name');
    expect(result.detail, contains('书名规则'));
  });

  test('detail stage rejects an unusable url before any request', () async {
    final result = await engine.testBookInfo(source(), '');

    expect(result.ok, isFalse);
    expect(result.field, 'bookUrl');
    expect(result.detail, contains('详情地址无效'));
  });

  test('catalog stage passes with a chapter sample', () async {
    final result = await engine.testToc(source(), '$base/toc');

    expect(result.ok, isTrue);
    expect(result.count, 2);
    expect(result.sample, '第一章 初入');
    expect(result.chapterUrl, '$base/read/1');
  });

  test('catalog stage blames chapterList when nothing matches', () async {
    final result = await engine.testToc(
      source(chapterList: '.missing-list li a'),
      '$base/toc',
    );

    expect(result.ok, isFalse);
    expect(result.field, 'chapterList');
    expect(result.detail, contains('列表规则'));
  });

  test('content stage passes with a head sample', () async {
    final result = await engine.testContent(source(), '$base/read/1');

    expect(result.ok, isTrue);
    expect(result.count, greaterThan(10));
    expect(result.sample, contains('正文'));
  });

  test('content stage blames the content rule when it misses', () async {
    // The page body carries text, but no configured rule and none of the
    // engine's common fallback containers match, so the stage must fail.
    final result = await engine.testContent(
      source(content: '#missing-content'),
      '$base/read/plain',
    );

    expect(result.ok, isFalse);
    expect(result.field, 'content');
    expect(result.detail, contains('正文规则'));
  });

  test('network failure reports the stage instead of throwing', () async {
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close(force: true);
    final payload = jsonEncode({
      'bookSourceUrl': 'http://127.0.0.1:$port',
      'bookSourceName': '断网源',
      'searchUrl': 'http://127.0.0.1:$port/search?q={{key}}',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text'},
      'ruleBookInfo': {'name': '.name'},
    });
    final dead = SourceImporter.parseJson(payload).sources.single;

    final result = await engine.testBookInfo(
      dead,
      'http://127.0.0.1:$port/book/1',
    );

    expect(result.ok, isFalse);
    expect(result.stage, 'bookInfo');
    expect(result.detail, isNotEmpty);
  });
}

const String _searchHtml = '''
<html><body>
<div class="item"><a href="/book/1">斗破苍穹</a></div>
</body></html>
''';

const String _detailHtml = '''
<html><body>
<h1 class="book-name">斗破苍穹</h1>
<a class="toc-link" href="/toc">目录</a>
</body></html>
''';

const String _tocHtml = '''
<html><body>
<ul class="catalog">
  <li><a href="/read/1">第一章 初入</a></li>
  <li><a href="/read/2">第二章 风起</a></li>
</ul>
</body></html>
''';

const String _contentHtml = '''
<html><body>
<div id="content">正文第一段。正文第二段，内容足够长以备抽样。</div>
</body></html>
''';

/// Body text in a container that matches neither the rule nor any engine
/// fallback selector.
const String _plainBodyHtml = '''
<html><body>
<div class="plain-body">这里的文字不匹配任何常见正文容器。</div>
</body></html>
''';
