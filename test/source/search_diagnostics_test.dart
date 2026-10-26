import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';

/// Loopback diagnostics: every failure mode must be distinguishable without
/// leaking query tokens into the report.
void main() {
  late _DiagnosticSite site;

  setUpAll(() async {
    site = await _DiagnosticSite.start();
  });

  tearDownAll(() => site.close());

  BookSource source(String path, {String listRule = '.item'}) {
    final payload = jsonEncode({
      'bookSourceUrl': site.base,
      'bookSourceName': '诊断测试源',
      'searchUrl': '${site.base}$path?q={{key}}&token=SECRET123&cookie=SESSION',
      'ruleSearch': {
        'bookList': listRule,
        'name': 'a@text',
        'author': '.author@text',
        'bookUrl': 'a@href',
      },
    });
    return SourceImporter.parseJson(payload).sources.single;
  }

  test('success returns hits and a redacted request URL', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/ok'),
      '斗破',
      1,
    );

    expect(report.issue, SourceSearchIssue.none);
    expect(report.ok, isTrue);
    expect(report.hits, hasLength(2));
    expect(report.hits.first.name, '斗破苍穹');
    expect(report.requestUrl, contains('/ok'));
    expect(report.requestUrl, isNot(contains('SECRET123')));
    expect(report.requestUrl, isNot(contains('SESSION')));
    expect(report.requestUrl, isNot(contains('token=')));
    expect(report.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('page without the keyword is a no-result, not a failure', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/empty'),
      '不存在的书',
      1,
    );

    expect(report.issue, SourceSearchIssue.noResult);
    expect(report.reachable, isTrue);
    expect(report.failed, isFalse);
    expect(report.hint, contains('没有匹配'));
  });

  test('keyword in page but list selector misses is a parse failure', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/parse'),
      '斗破',
      1,
    );

    expect(report.issue, SourceSearchIssue.parse);
    expect(report.failed, isTrue);
    expect(report.detail, contains('列表规则'));
  });

  test('items without usable book links are a parse failure', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/nourl'),
      '斗破',
      1,
    );

    expect(report.issue, SourceSearchIssue.parse);
    expect(report.rawItems, 1);
    expect(report.hits, isEmpty);
  });

  test('missing search URL is an incompatible rule', () async {
    final payload = jsonEncode({
      'bookSourceUrl': site.base,
      'bookSourceName': '无搜索源',
      'searchUrl': '',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text'},
    });
    final src = SourceImporter.parseJson(payload).sources.single;
    final report = await BookSourceEngine().searchWithReport(src, '斗破', 1);

    expect(report.issue, SourceSearchIssue.incompatibleRule);
    expect(report.hint, contains('未配置搜索地址'));
  });

  test('empty list rule is an incompatible rule', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/ok', listRule: ''),
      '斗破',
      1,
    );

    expect(report.issue, SourceSearchIssue.incompatibleRule);
    expect(report.detail, contains('列表规则'));
  });

  test('unresolvable search URL is an incompatible rule', () async {
    final payload = jsonEncode({
      'bookSourceUrl': site.base,
      'bookSourceName': '坏地址源',
      'searchUrl': '<js>let a = 1;</js>',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text'},
    });
    final src = SourceImporter.parseJson(payload).sources.single;
    final report = await BookSourceEngine().searchWithReport(src, '斗破', 1);

    expect(report.issue, SourceSearchIssue.incompatibleRule);
    expect(report.hint, contains('无法解析'));
  });

  test('connection refused is a network failure', () async {
    final closed = await _DiagnosticSite.start();
    final port = closed.port;
    await closed.close();

    final payload = jsonEncode({
      'bookSourceUrl': 'http://127.0.0.1:$port',
      'bookSourceName': '断网源',
      'searchUrl': 'http://127.0.0.1:$port/search?q={{key}}',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text'},
    });
    final src = SourceImporter.parseJson(payload).sources.single;
    final report = await BookSourceEngine().searchWithReport(src, '斗破', 1);

    expect(report.issue, SourceSearchIssue.network);
    expect(report.failed, isTrue);
  });

  test('slow source is a timeout', () async {
    final report = await BookSourceEngine().searchWithReport(
      source('/slow'),
      '斗破',
      1,
      timeout: const Duration(milliseconds: 120),
    );

    expect(report.issue, SourceSearchIssue.timeout);
    expect(report.detail, contains('120'));
  });

  test('legacy search still returns hits', () async {
    final hits = await BookSourceEngine().search(source('/ok'), '斗破', 1);
    expect(hits, hasLength(2));
  });
}

class _DiagnosticSite {
  _DiagnosticSite._(this._server) : base = 'http://127.0.0.1:${_server.port}';

  final HttpServer _server;
  final String base;
  int get port => _server.port;

  static Future<_DiagnosticSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _DiagnosticSite._(server);
    server.listen(site._handle);
    return site;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.html;
    switch (request.uri.path) {
      case '/ok':
        response.write(_okHtml);
      case '/empty':
        response.write(_emptyHtml);
      case '/parse':
        response.write(_parseHtml);
      case '/nourl':
        response.write(_nourlHtml);
      case '/slow':
        await Future<void>.delayed(const Duration(seconds: 2));
        response.write(_okHtml);
      default:
        response.statusCode = HttpStatus.notFound;
        response.write('<html><body>not found</body></html>');
    }
    await response.close();
  }

  static const String _okHtml = '''
<html><body>
<div class="item"><a href="/book/1">斗破苍穹</a><span class="author">天蚕土豆</span></div>
<div class="item"><a href="/book/2">武动乾坤</a><span class="author">天蚕土豆</span></div>
</body></html>
''';

  static const String _emptyHtml = '''
<html><body><div class="notice">今日推荐</div></body></html>
''';

  static const String _parseHtml = '''
<html><body><div class="notice">斗破苍穹 搜索结果</div></body></html>
''';

  static const String _nourlHtml = '''
<html><body>
<div class="item"><a>斗破苍穹</a></div>
</body></html>
''';
}
