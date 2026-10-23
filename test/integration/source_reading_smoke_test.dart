import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/repositories/reading_history_repository.dart';
import 'package:langhuan/features/reader/model/reading_progress_store.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/util/book_id.dart';

/// End-to-end smoke for the remote reading path:
/// import source JSON → search → detail → toc → chapter body → progress save.
///
/// The book source is a local loopback HTTP server, so this runs offline.
/// Progress persistence uses in-memory fakes; the real SQLite write is covered
/// by on-device acceptance.
void main() {
  test('冒烟：导入书源 → 搜索 → 详情 → 阅读 → 记录进度', () async {
    final site = await _FakeSourceSite.start();
    addTearDown(site.close);

    // 1. 导入：解析 Legado JSON，并按数据库 raw_json 的方式回读。
    final payload = jsonEncode({
      'bookSourceUrl': site.base,
      'bookSourceName': '冒烟书源',
      'bookSourceGroup': '测试',
      'header': jsonEncode({'X-Smoke': '1'}),
      'searchUrl': '${site.base}/search?q={{key}}&page={{page}}',
      'ruleSearch': {
        'bookList': '.result .item',
        'name': 'a.title@text',
        'author': '.author@text',
        'kind': '.kind@text',
        'lastChapter': '.latest@text',
        'intro': '.intro@text',
        'coverUrl': 'img@src',
        'bookUrl': 'a.title@href',
      },
      'ruleBookInfo': {
        'name': 'h1.book-name@text',
        'author': '.book-author@text',
        'coverUrl': 'meta[property="og:image"]@content',
        'intro': '#intro@text',
        'tocUrl': 'a.toc@href',
      },
      'ruleToc': {
        'chapterList': '#catalog li',
        'chapterName': 'a@text',
        'chapterUrl': 'a@href',
      },
      'ruleContent': {
        'content': '#content',
        'replaceRegex': '本站提供免费阅读，请支持正版。##',
      },
    });

    final imported = SourceImporter.parseJson(payload);
    expect(imported.sources, hasLength(1));
    final source = imported.sources.single;
    expect(source.bookSourceUrl, site.base);
    expect(source.rawJson, isNotEmpty);

    final reloaded = BookSource.fromLegadoJson(
      Map<String, dynamic>.from(jsonDecode(source.rawJson) as Map),
    );
    expect(reloaded.enabled, isTrue);
    expect(reloaded.searchUrl, source.searchUrl);
    expect(reloaded.ruleSearch.bookList, '.result .item');

    final engine = BookSourceEngine();

    // 2. 搜索：懒加载封面取 data-src，相对地址补全。
    final hits = await engine.search(reloaded, '测试', 1);
    expect(hits, hasLength(1));
    final hit = hits.single;
    expect(hit.name, '测试之书');
    expect(hit.author, '林墨');
    expect(hit.bookUrl, '${site.base}/book/1');
    expect(hit.coverUrl, '${site.base}/cover/1.jpg');

    // 3. 详情：搜索页下发的 Cookie 必须带到详情请求。
    final info = await engine.bookInfo(reloaded, hit.bookUrl, seed: hit);
    expect(info.name, '测试之书');
    expect(info.author, '林墨');
    expect(info.coverUrl, hit.coverUrl);
    expect(info.tocUrl, '${site.base}/toc/1');
    expect(site.cookieSeenOn('/book/1'), isTrue);

    // 4. 目录。
    final chapters = await engine.toc(reloaded, info.tocUrl);
    expect(chapters, hasLength(2));
    expect(chapters[0].name, '第一章 启程');
    expect(chapters[1].name, '第二章 风起');
    expect(chapters[1].url, '${site.base}/read/2');
    expect(site.cookieSeenOn('/toc/1'), isTrue);

    // 5. 阅读正文：清洗广告、去脚本、段首缩进。
    final body = await engine.content(reloaded, chapters[1].url);
    expect(body, contains('第一段测试正文'));
    expect(body, contains('第二段测试正文'));
    expect(body, isNot(contains('免费阅读')));
    expect(body, isNot(contains('广告位')));
    expect(body, isNot(contains('tracking')));
    final lines = body.split('\n').where((line) => line.isNotEmpty).toList();
    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(line.startsWith('　　'), isTrue, reason: '段落应带首行缩进：$line');
    }
    expect(site.cookieSeenOn('/read/2'), isTrue);

    // 书源 header 应出现在每个引擎请求上。
    expect(
      site.requests.map((request) => request.smokeHeader).toSet(),
      {'1'},
    );

    // 6. 记录进度：真实走 ReadingProgressStore，落到内存假仓储。
    final book = info.toBook()
      ..chapterIndex = 1
      ..pageIndex = 2
      ..scrollOffset = 36.5;
    final tocEntries = [
      for (final chapter in chapters)
        ChapterTocEntry(
          id: makeChapterId(book.id, chapter.url),
          title: chapter.name,
          url: chapter.url,
          ord: chapter.index,
        ),
    ];

    final books = _FakeBookRepository();
    final chapterRepo = _FakeChapterRepository();
    final history = _FakeReadingHistoryRepository();
    final ensured = <String>[];
    final store = ReadingProgressStore(
      books: books,
      chapters: chapterRepo,
      history: history,
      ensureBookRow: (value) async => ensured.add(value.id),
    )..ready = true;

    await store.flush(book: book, chapters: tocEntries);

    expect(ensured, [book.id]);
    expect(books.savedBookId, book.id);
    expect(books.savedChapterIndex, 1);
    expect(books.savedPageIndex, 2);
    expect(books.savedScrollOffset, 36.5);
    expect(books.savedReadingChapter, '第二章 风起');

    expect(chapterRepo.syncedBookId, book.id);
    expect(
      chapterRepo.syncedChapters.map((chapter) => chapter.title).toList(),
      ['第一章 启程', '第二章 风起'],
    );
    expect(chapterRepo.syncedSourceUrl, reloaded.bookSourceUrl);

    expect(history.touchedBookId, book.id);
    expect(history.touchedChapterIndex, 1);
    expect(history.touchedPageIndex, 2);
    expect(history.touchedChapterName, '第二章 风起');
    expect(book.readingChapter, '第二章 风起');
  });
}

class _RequestLog {
  _RequestLog({
    required this.path,
    required this.smokeHeader,
    required this.cookie,
  });

  final String path;
  final String smokeHeader;
  final String cookie;
}

/// Minimal novel site: search, detail, toc, chapter pages, all on loopback.
class _FakeSourceSite {
  _FakeSourceSite._(this._server) : base = 'http://127.0.0.1:${_server.port}';

  final HttpServer _server;
  final String base;
  final List<_RequestLog> requests = [];

  static Future<_FakeSourceSite> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _FakeSourceSite._(server);
    server.listen(site._handle);
    return site;
  }

  Future<void> close() => _server.close(force: true);

  bool cookieSeenOn(String path) => requests.any(
    (request) => request.path == path && request.cookie.contains('sid=smoke123'),
  );

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add(
      _RequestLog(
        path: path,
        smokeHeader: request.headers.value('x-smoke') ?? '',
        cookie: request.headers.value('cookie') ?? '',
      ),
    );

    final response = request.response;
    response.headers.contentType = ContentType.html;
    try {
      switch (path) {
        case '/search':
          response.headers.add('set-cookie', 'sid=smoke123; Path=/; HttpOnly');
          _writeHtml(response, _searchHtml);
        case '/book/1':
          _writeHtml(
            response,
            _hasSession(request)
                ? _detailHtml
                : '<html><body>forbidden</body></html>',
            status: _hasSession(request) ? HttpStatus.ok : HttpStatus.forbidden,
          );
        case '/toc/1':
          _writeHtml(
            response,
            _hasSession(request)
                ? _tocHtml
                : '<html><body>forbidden</body></html>',
            status: _hasSession(request) ? HttpStatus.ok : HttpStatus.forbidden,
          );
        case '/read/2':
          _writeHtml(
            response,
            _hasSession(request)
                ? _chapterHtml
                : '<html><body>forbidden</body></html>',
            status: _hasSession(request) ? HttpStatus.ok : HttpStatus.forbidden,
          );
        default:
          _writeHtml(response, '<html><body>not found</body></html>',
              status: HttpStatus.notFound);
      }
    } finally {
      await response.close();
    }
  }

  bool _hasSession(HttpRequest request) =>
      (request.headers.value('cookie') ?? '').contains('sid=smoke123');

  void _writeHtml(HttpResponse response, String html, {int status = 200}) {
    response.statusCode = status;
    response.write(html);
  }

  static const String _searchHtml = '''
<html><body>
<div class="result">
  <div class="item">
    <a class="title" href="/book/1">测试之书</a>
    <span class="author">作者：林墨</span>
    <span class="kind">玄幻</span>
    <span class="latest">第二章 风起</span>
    <p class="intro">一本用于冒烟测试的书。</p>
    <img src="/static/loading.jpg" data-src="/cover/1.jpg" alt="封面">
  </div>
</div>
</body></html>
''';

  static const String _detailHtml = '''
<html><head>
<meta property="og:image" content="/cover/1.jpg">
</head><body>
<h1 class="book-name">测试之书</h1>
<p class="book-author">作者：林墨</p>
<p id="intro">一本用于冒烟测试的书。</p>
<a class="toc" href="/toc/1">查看目录</a>
</body></html>
''';

  static const String _tocHtml = '''
<html><body>
<ul id="catalog">
  <li><a href="/read/1">第一章 启程</a></li>
  <li><a href="/read/2">第二章 风起</a></li>
</ul>
</body></html>
''';

  static const String _chapterHtml = '''
<html><body>
<div class="ad">广告位</div>
<div id="content">
<p>第一段测试正文，主角在雨夜出发。</p>
<p>第二段测试正文，补足章节内容。</p>
<p>本站提供免费阅读，请支持正版。</p>
</div>
<script>var tracking = 1;</script>
</body></html>
''';
}

class _FakeBookRepository extends BookRepository {
  String? savedBookId;
  int? savedChapterIndex;
  int? savedPageIndex;
  double? savedScrollOffset;
  String? savedReadingChapter;

  @override
  Future<int> saveProgress({
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    double scrollOffset = 0,
    String? readingChapter,
  }) async {
    savedBookId = bookId;
    savedChapterIndex = chapterIndex;
    savedPageIndex = pageIndex;
    savedScrollOffset = scrollOffset;
    savedReadingChapter = readingChapter;
    return 1;
  }
}

class _FakeChapterRepository extends ChapterRepository {
  String? syncedBookId;
  String? syncedSourceUrl;
  List<ChapterTocEntry> syncedChapters = const [];

  @override
  Future<int> count(String bookId) async => 0;

  @override
  Future<void> syncToc(
    List<ChapterTocEntry> chapters,
    String bookId, {
    String sourceUrl = '',
  }) async {
    syncedChapters = List<ChapterTocEntry>.from(chapters);
    syncedBookId = bookId;
    syncedSourceUrl = sourceUrl;
  }
}

class _FakeReadingHistoryRepository extends ReadingHistoryRepository {
  String? touchedBookId;
  int? touchedChapterIndex;
  int? touchedPageIndex;
  String? touchedChapterName;

  @override
  Future<void> touch({
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    required String chapterName,
  }) async {
    touchedBookId = bookId;
    touchedChapterIndex = chapterIndex;
    touchedPageIndex = pageIndex;
    touchedChapterName = chapterName;
  }
}
