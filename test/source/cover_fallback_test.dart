import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';

/// Covers lazy-loading image attributes and relative URL resolution on both
/// the search list and the detail page. Runs against a loopback site.
void main() {
  test('list and detail resolve lazy / relative cover URLs', () async {
    final site = await _CoverSite.start();
    addTearDown(site.close);

    final payload = jsonEncode({
      'bookSourceUrl': site.base,
      'bookSourceName': '封面测试源',
      'searchUrl': '${site.base}/search?q={{key}}',
      'ruleSearch': {
        'bookList': '.result .item',
        'name': 'a.title@text',
        'coverUrl': 'img@src',
        'bookUrl': 'a.title@href',
      },
      'ruleBookInfo': {'name': 'h1@text', 'coverUrl': 'img.cover@src'},
    });
    final source = SourceImporter.parseJson(payload).sources.single;
    final engine = BookSourceEngine();

    final hits = await engine.search(source, '封面', 1);
    expect(hits, hasLength(2));
    // data-original wins over the shared loading.gif in src.
    expect(hits[0].coverUrl, '${site.base}/cover/1.jpg');
    // A CSS background image is used when every image attribute is a placeholder.
    expect(hits[1].coverUrl, '${site.base}/cover/2.jpg');

    // Detail page has no og:image; the cover lives in data-src only.
    final info = await engine.bookInfo(source, '${site.base}/book/2');
    expect(info.coverUrl, '${site.base}/cover/2.jpg');

    // Cover-only lookup used by list enrichment: absolute URL or empty.
    expect(
      await engine.fetchCover(source, '${site.base}/book/2'),
      '${site.base}/cover/2.jpg',
    );
    expect(
      await engine.fetchCover(
        source,
        '${site.base}/missing',
        timeout: const Duration(milliseconds: 300),
      ),
      isEmpty,
    );
  });
}

class _CoverSite {
  _CoverSite._(this._server) : base = 'http://127.0.0.1:${_server.port}';

  final HttpServer _server;
  final String base;

  static Future<_CoverSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _CoverSite._(server);
    server.listen(site._handle);
    return site;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.html;
    switch (request.uri.path) {
      case '/search':
        response.write(_searchHtml);
      case '/book/2':
        response.write(_detailHtml);
      default:
        response.statusCode = HttpStatus.notFound;
        response.write('<html><body>not found</body></html>');
    }
    await response.close();
  }

  static const String _searchHtml = '''
<html><body>
<div class="result">
  <div class="item">
    <a class="title" href="/book/1">懒加载</a>
    <img src="/static/loading.jpg" data-original="/cover/1.jpg">
  </div>
  <div class="item">
    <a class="title" href="/book/2">样式封面</a>
    <img src="/static/loading.jpg" style="background-image:url('/cover/2.jpg')">
  </div>
</div>
</body></html>
''';

  static const String _detailHtml = '''
<html><body>
<h1>样式封面</h1>
<div class="cover">
  <img src="/static/loading.jpg" data-src="/cover/2.jpg">
</div>
</body></html>
''';
}
