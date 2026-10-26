import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';

/// 阅友小说 (m.suixkan.com) keeps the detail link in an inline handler:
///   <div class="v-list-item" onclick="newWebView('/b/229093.html', '', '')">
/// Its rule set is `@onclick@js:result.match(/\('(.*?)', '', ''\)/)[1]`.
/// When the JS runtime is unavailable the transform returns its input, so
/// tests accept either form — both prove the head rule ran before the JS.
const String _handler = "newWebView('/b/229093.html', '', '')";
const String _bookPath = '/b/229093.html';

void main() {
  group('@onclick attribute', () {
    const html = '''
<html><body>
<div class="v-list">
  <div class="v-list-item flex" onclick="$_handler">
    <div class="v-title">灵破苍穹</div>
    <div class="v-author">心跳的瞬间&nbsp;</div>
  </div>
  <div class="v-list-item flex">
    <div class="v-title">无链接</div>
  </div>
  <a class="plain" href="/book/2" onclick="openBook('2')">武动乾坤</a>
</div>
</body></html>
''';

    final rule = AnalyzeRule(
      content: html,
      baseUrl: 'http://m.suixkan.com/s/1.html?keyword=%E6%96%97%E7%A0%B4',
    );
    final doc = rule.doc;

    test('bare @onclick returns the handler', () {
      final scope = doc.querySelector('.v-list-item')!;
      expect(rule.getString('@onclick', scope: scope), _handler);
    });

    test('selector@onclick reads a nested anchor', () {
      final scope = doc.querySelector('.v-list')!;
      expect(rule.getString('.plain@onclick', scope: scope), "openBook('2')");
    });

    test('missing handler stays empty, not card text', () {
      final scope = doc.querySelectorAll('.v-list-item')[1];
      expect(rule.getString('@onclick', scope: scope), isEmpty);
    });

    test('href rules keep working', () {
      final scope = doc.querySelector('.plain')!;
      expect(rule.getString('@href', scope: scope), '/book/2');
    });

    test('search bookUrl rule extracts the path', () {
      final scope = doc.querySelector('.v-list-item')!;
      final out = rule.getString(
        r"@onclick@js:result.match(/\('(.*?)', '', ''\)/)[1]",
        scope: scope,
      );
      // No JS runtime (desktop tests): raw handler. Android: extracted path.
      expect(out, anyOf(_handler, _bookPath));
    });

    test('explore bookUrl rule uses its own regex', () {
      final scope = doc.querySelector('.v-list-item')!;
      final out = rule.getString(
        r"@onclick@js:result.match(/\('(.*?)'\)/)[1]",
        scope: scope,
      );
      expect(out, anyOf(_handler, _bookPath));
    });

    test('|| and && inside trailing JS are not split as rule operators', () {
      final scope = doc.querySelector('.v-list-item')!;
      expect(
        rule.getString("@onclick@js:result || 'x'", scope: scope),
        _handler,
      );
      expect(
        rule.getString("@onclick@js:result && 'x'", scope: scope),
        _handler,
      );
    });
  });

  group('sanitizeUrl rejects handler leftovers', () {
    test('javascript / mailto / anchors are not links', () {
      expect(AnalyzeUrl.sanitizeUrl('javascript:;', base: 'https://ex.com'), '');
      expect(
        AnalyzeUrl.sanitizeUrl('javascript:openBook(1)', base: 'https://ex.com'),
        '',
      );
      expect(AnalyzeUrl.sanitizeUrl('mailto:a@b.c', base: 'https://ex.com'), '');
      expect(AnalyzeUrl.sanitizeUrl('#', base: 'https://ex.com'), '');
      expect(AnalyzeUrl.sanitizeUrl('#top', base: 'https://ex.com'), '');
    });

    test('inline handler body is not joined onto the host', () {
      expect(
        AnalyzeUrl.sanitizeUrl(_handler, base: 'http://m.suixkan.com/s/1.html'),
        isEmpty,
      );
    });

    test('extracted book path resolves against the source host', () {
      expect(
        AnalyzeUrl.sanitizeUrl(_bookPath, base: 'http://m.suixkan.com/s/1.html'),
        'http://m.suixkan.com$_bookPath',
      );
    });
  });

  group('search falls back to the card link', () {
    late HttpServer server;
    late String base;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        final response = request.response
          ..headers.contentType = ContentType.html
          ..write(_searchHtml);
        await response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('handler leftovers are rejected, real card links are used', () async {
      final payload = jsonEncode({
        'bookSourceUrl': base,
        'bookSourceName': '点击测试源',
        'searchUrl': '$base/s/1.html?keyword={{key}}&page={{page}}',
        'ruleSearch': {
          'bookList': '.v-list-item',
          'name': '.v-title@text',
          'author': '.v-author@text',
          'bookUrl': 'a.v-title@onclick',
        },
      });
      final source = SourceImporter.parseJson(payload).sources.single;

      final hits = await BookSourceEngine().search(source, '斗破', 1);

      expect(hits, hasLength(2));
      expect(hits[0].name, '灵破苍穹');
      expect(hits[0].bookUrl, '$base/book/1');
      // Dead href → data-href recovery.
      expect(hits[1].name, '武动乾坤');
      expect(hits[1].bookUrl, '$base/book/2');
    });
  });
}

/// Two cards: one with a real href, one with a dead href and data-href.
const String _searchHtml = '''
<html><body>
<div class="v-list">
  <div class="v-list-item">
    <a class="v-title" href="/book/1"
       onclick="openBook('1', '', '')">灵破苍穹</a>
    <div class="v-author">心跳的瞬间</div>
  </div>
  <div class="v-list-item">
    <a class="v-title" href="javascript:;" data-href="/book/2"
       onclick="openBook('2', '', '')">武动乾坤</a>
    <div class="v-author">天蚕土豆</div>
  </div>
</div>
</body></html>
''';
