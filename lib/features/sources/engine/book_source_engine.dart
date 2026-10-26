import 'dart:async';

import 'package:dio/dio.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/features/sources/analyzer/js_analyzer.dart';
import 'package:langhuan/features/sources/analyzer/regex_analyzer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_diagnostics.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/net/source_http.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';
import 'package:langhuan/features/sources/util/url_join.dart';
import 'package:html/dom.dart';

/// Core pipeline: search / explore / detail / toc / content via book-source rules.
class BookSourceEngine {
  static const int maxTocPages = 30;
  static const int maxContentPages = 20;
  static const Duration sourceTimeout = Duration(seconds: 12);

  Future<List<SearchBook>> search(
    BookSource source,
    String key,
    int page,
  ) async {
    if (source.searchUrl.isEmpty || key.isEmpty) return const [];
    AppLog.d('Source', 'search "${source.bookSourceName}" key=$key page=$page');
    try {
      final run = await _runSearch(source, key, page);
      return run.books;
    } catch (e, st) {
      AppLog.e(
        'SourceNet',
        'search fail "${source.bookSourceName}" key=$key',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Search one source and classify the outcome for diagnostics.
  ///
  /// Never throws: network, timeout and parse failures become a
  /// [SourceSearchReport] so a sweep can keep going and the UI can offer a
  /// per-source retry.
  Future<SourceSearchReport> searchWithReport(
    BookSource source,
    String key,
    int page, {
    Duration timeout = sourceTimeout,
  }) async {
    final sw = Stopwatch()..start();
    var requestUrl = '';
    try {
      final run = await _runSearch(
        source,
        key,
        page,
        timeout: timeout,
        onRequestUrl: (url) => requestUrl = url,
      );
      sw.stop();
      final report = _classifyReport(source, key, page, run, sw.elapsedMilliseconds);
      AppLog.i(
        'Source',
        'search report "${source.bookSourceName}" ${report.label} '
            'hits=${report.hits.length} ${report.elapsedMs}ms '
            'url=${report.requestUrl}',
      );
      return report;
    } on TimeoutException {
      sw.stop();
      return _failedReport(
        source,
        key,
        page,
        SourceSearchIssue.timeout,
        detail: '超过 ${_durationLabel(timeout)}未响应。',
        elapsedMs: sw.elapsedMilliseconds,
        requestUrl: requestUrl,
      );
    } on DioException catch (e) {
      sw.stop();
      final issue =
          e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.transformTimeout
          ? SourceSearchIssue.timeout
          : SourceSearchIssue.network;
      return _failedReport(
        source,
        key,
        page,
        issue,
        detail: _dioDetail(e),
        elapsedMs: sw.elapsedMilliseconds,
        requestUrl: requestUrl,
        httpStatus: e.response?.statusCode ?? 0,
      );
    } on ArgumentError {
      sw.stop();
      return _failedReport(
        source,
        key,
        page,
        SourceSearchIssue.incompatibleRule,
        detail: source.searchUrl.trim().isEmpty
            ? '未配置搜索地址。'
            : '搜索地址无法解析，可能是 JS 规则未执行。',
        elapsedMs: sw.elapsedMilliseconds,
        requestUrl: requestUrl,
      );
    } catch (e, st) {
      sw.stop();
      AppLog.w(
        'SourceNet',
        'search report failed "${source.bookSourceName}"',
        error: e,
      );
      AppLog.d('SourceNet', 'search report stack: $st');
      return _failedReport(
        source,
        key,
        page,
        SourceSearchIssue.unknown,
        detail: '请求或解析异常（${Redact.errorType(e)}）。',
        elapsedMs: sw.elapsedMilliseconds,
        requestUrl: requestUrl,
      );
    }
  }

  Future<_SearchRun> _runSearch(
    BookSource source,
    String key,
    int page, {
    Duration timeout = sourceTimeout,
    void Function(String url)? onRequestUrl,
  }) async {
    final request = AnalyzeUrl.build(
      source,
      source.searchUrl,
      key: key,
      page: page,
    );
    onRequestUrl?.call(request.url);
    final resp = await SourceHttp.instance.fetch(request).timeout(timeout);
    final listRule = source.ruleSearch.bookList;
    final parsed = _parseBookList(
      source,
      resp,
      listRule: listRule,
      nameRule: source.ruleSearch.name,
      authorRule: source.ruleSearch.author,
      kindRule: source.ruleSearch.kind,
      wordCountRule: source.ruleSearch.wordCount,
      lastChapterRule: source.ruleSearch.lastChapter,
      introRule: source.ruleSearch.intro,
      coverRule: source.ruleSearch.coverUrl,
      bookUrlRule: source.ruleSearch.bookUrl,
      logTag: 'search',
    );
    var keyInBody = resp.body.contains(key);
    if (!keyInBody) {
      final lower = key.toLowerCase();
      if (lower != key) keyInBody = resp.body.toLowerCase().contains(lower);
    }
    return _SearchRun(
      books: parsed.books,
      rawItems: parsed.rawItems,
      dropped: parsed.dropped,
      requestUrl: request.url,
      bodyLength: resp.body.length,
      keyInBody: keyInBody,
      httpStatus: resp.statusCode,
      listRule: listRule,
    );
  }

  SourceSearchReport _classifyReport(
    BookSource source,
    String key,
    int page,
    _SearchRun run,
    int elapsedMs,
  ) {
    final base = SourceSearchReport(
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      keyword: key,
      page: page,
      issue: SourceSearchIssue.none,
      hits: run.books,
      elapsedMs: elapsedMs,
      requestUrl: Redact.url(run.requestUrl),
      httpStatus: run.httpStatus,
      rawItems: run.rawItems,
    );
    if (run.books.isNotEmpty) return base;

    if (run.listRule.trim().isEmpty) {
      return _copy(
        base,
        SourceSearchIssue.incompatibleRule,
        '未配置搜索列表规则。',
      );
    }
    if (run.rawItems == 0) {
      if (run.keyInBody) {
        return _copy(
          base,
          SourceSearchIssue.parse,
          '页面包含关键词，但列表规则没有匹配到条目'
              '（${run.listRule}，页面 ${run.bodyLength} 字节）。',
        );
      }
      return _copy(base, SourceSearchIssue.noResult, '页面已返回，但未找到「$key」。');
    }
    return _copy(
      base,
      SourceSearchIssue.parse,
      '匹配到 ${run.rawItems} 个条目，但书名或详情链接规则未取到'
          '${run.dropped > 0 ? '（丢弃 ${run.dropped} 条）' : ''}。',
    );
  }

  SourceSearchReport _failedReport(
    BookSource source,
    String key,
    int page,
    SourceSearchIssue issue, {
    required String detail,
    required int elapsedMs,
    required String requestUrl,
    int httpStatus = 0,
  }) {
    return SourceSearchReport(
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      keyword: key,
      page: page,
      issue: issue,
      elapsedMs: elapsedMs,
      requestUrl: Redact.url(requestUrl),
      detail: detail,
      httpStatus: httpStatus,
    );
  }

  SourceSearchReport _copy(
    SourceSearchReport base,
    SourceSearchIssue issue,
    String detail,
  ) {
    return SourceSearchReport(
      sourceUrl: base.sourceUrl,
      sourceName: base.sourceName,
      keyword: base.keyword,
      page: base.page,
      issue: issue,
      hits: base.hits,
      elapsedMs: base.elapsedMs,
      requestUrl: base.requestUrl,
      detail: detail,
      httpStatus: base.httpStatus,
      rawItems: base.rawItems,
    );
  }

  String _durationLabel(Duration d) =>
      d.inSeconds >= 1 ? '${d.inSeconds} 秒' : '${d.inMilliseconds} 毫秒';

  String _dioDetail(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return '连接书源超时。';
      case DioExceptionType.badCertificate:
        return 'HTTPS 证书校验失败。';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code > 0 ? '站点返回 HTTP $code。' : '站点返回异常响应。';
      case DioExceptionType.connectionError:
        return '无法连接书源站点，请检查网络或站点状态。';
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.unknown:
        return '网络请求失败，请检查网络或站点状态。';
    }
  }

  /// Discover / category list via [url] template (`{{page}}` filled by AnalyzeUrl).
  /// List fields prefer [BookSource.ruleExplore], fall back to [BookSource.ruleSearch].
  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) async {
    if (url.isEmpty) return const [];
    AppLog.d(
      'Source',
      'explore "${source.bookSourceName}" page=$page url=${Redact.forLog(url)}',
    );
    try {
      final resp = await AnalyzeUrl.fetch(
        source,
        url,
        page: page,
      ).timeout(sourceTimeout);
      final er = source.ruleExplore;
      final sr = source.ruleSearch;
      String pick(String a, String b) => a.isNotEmpty ? a : b;
      return _parseBookList(
        source,
        resp,
        listRule: pick(er.bookList, sr.bookList),
        nameRule: pick(er.name, sr.name),
        authorRule: pick(er.author, sr.author),
        kindRule: pick(er.kind, sr.kind),
        wordCountRule: pick(er.wordCount, sr.wordCount),
        lastChapterRule: pick(er.lastChapter, sr.lastChapter),
        introRule: pick(er.intro, sr.intro),
        coverRule: pick(er.coverUrl, sr.coverUrl),
        bookUrlRule: pick(er.bookUrl, sr.bookUrl),
        logTag: 'explore',
      ).books;
    } catch (e, st) {
      AppLog.e(
        'SourceNet',
        'explore fail "${source.bookSourceName}" url=${Redact.forLog(url)}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  _ParsedBookList _parseBookList(
    BookSource source,
    SourceResponse resp, {
    required String listRule,
    required String nameRule,
    required String authorRule,
    required String kindRule,
    required String wordCountRule,
    required String lastChapterRule,
    required String introRule,
    required String coverRule,
    required String bookUrlRule,
    required String logTag,
  }) {
    final rule = AnalyzeRule(
      content: resp.body,
      baseUrl: resp.url,
      isJson: resp.isJson,
      jsLib: source.jsLib,
    );
    final items = listRule.isEmpty ? const <dynamic>[] : rule.getList(listRule);
    if (listRule.isNotEmpty && items.isEmpty) {
      AppLog.w(
        'RuleMiss',
        '$logTag list empty "${source.bookSourceName}" '
            'rule="$listRule" bodyLen=${resp.body.length}',
      );
    }
    final out = <SearchBook>[];
    var dropped = 0;
    final checkKey = source.ruleSearch.checkKeyWord.trim();
    for (final item in items) {
      final name = rule.getString(nameRule, scope: item);
      if (name.isEmpty) {
        dropped++;
        continue;
      }
      if (checkKey.isNotEmpty && name.contains(checkKey)) {
        // Legado checkKeyWord: drop captcha / soft-404 result rows.
        dropped++;
        continue;
      }
      var bookUrl = rule.getString(bookUrlRule, scope: item);
      if (bookUrl.isNotEmpty) {
        bookUrl = AnalyzeUrl.sanitizeUrl(bookUrl, base: resp.url);
      }
      if (bookUrl.isEmpty && item is Element) {
        // Rule missed or produced a handler/JS leftover: recover the card's
        // real link from href / data-href instead of dropping the hit.
        final anchor = item.querySelector('a');
        final candidates = <String>[
          item.attributes['href'] ?? '',
          anchor?.attributes['href'] ?? '',
          item.attributes['data-href'] ?? '',
          anchor?.attributes['data-href'] ?? '',
          item.attributes['data-url'] ?? '',
          anchor?.attributes['data-url'] ?? '',
        ];
        for (final candidate in candidates) {
          if (candidate.isEmpty) continue;
          bookUrl = AnalyzeUrl.sanitizeUrl(candidate, base: resp.url);
          if (bookUrl.isNotEmpty) break;
        }
      }
      if (bookUrl.isEmpty) {
        AppLog.d('RuleMiss', 'skip item without usable bookUrl name=$name');
        dropped++;
        continue;
      }
      var cover = rule.getString(coverRule, scope: item);
      if ((cover.isEmpty || _isPlaceholderCover(cover)) && item is Element) {
        cover = _coverFromElement(item);
      }
      if (cover.isNotEmpty) cover = urlJoin(resp.url, cover);
      if (_isPlaceholderCover(cover)) cover = '';
      out.add(
        SearchBook(
          name: name,
          author: _resolveAuthor(rule, ruleStr: authorRule, scope: item),
          kind: rule.getString(kindRule, scope: item),
          wordCount: rule.getString(wordCountRule, scope: item),
          lastChapter: rule.getString(lastChapterRule, scope: item),
          intro: rule.getString(introRule, scope: item),
          coverUrl: cover,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        ),
      );
    }
    AppLog.i(
      'Source',
      '$logTag ok "${source.bookSourceName}" hits=${out.length}',
    );
    return _ParsedBookList(
      out,
      rawItems: items.length,
      dropped: dropped,
    );
  }

  Future<BookInfo> bookInfo(
    BookSource source,
    String bookUrl, {
    SearchBook? seed,
  }) async {
    final resolved = AnalyzeUrl.sanitizeUrl(
      bookUrl,
      base: source.bookSourceUrl,
    );
    if (resolved.isEmpty) {
      throw SourceStageError(
        stage: 'bookInfo',
        field: 'bookUrl',
        rule: bookUrl,
        detail: '详情地址无效',
      );
    }
    try {
      return await _bookInfo(source, resolved, seed: seed);
    } on SourceStageError {
      rethrow;
    } catch (e, st) {
      AppLog.e(
        'SourceNet',
        'bookInfo fail "${source.bookSourceName}" '
            'url=${Redact.forLog(resolved)}',
        error: e,
        stackTrace: st,
      );
      throw SourceStageError(
        stage: 'bookInfo',
        field: 'bookUrl',
        rule: bookUrl,
        detail: _stageDetail(e),
        cause: e,
      );
    }
  }

  Future<BookInfo> _bookInfo(
    BookSource source,
    String bookUrl, {
    SearchBook? seed,
  }) async {
    final resp = await AnalyzeUrl.fetch(
      source,
      '',
      absoluteUrl: bookUrl,
    ).timeout(sourceTimeout);
    // Legado ruleBookInfo.init may narrow/transform the page before field rules.
    final body = _applyInitRule(
      resp.body,
      source.ruleBookInfo.init,
      baseUrl: resp.url,
      isJson: resp.isJson,
      jsLib: source.jsLib,
    );
    final rule = AnalyzeRule(
      content: body,
      baseUrl: resp.url,
      isJson: resp.isJson || _looksJson(body),
      jsLib: source.jsLib,
    );
    final r = source.ruleBookInfo;
    String pick(String ruleStr, String fallback) {
      final v = rule.getString(ruleStr);
      return v.isNotEmpty ? v : fallback;
    }

    final cover = _resolveCover(source, resp, rule, seed?.coverUrl ?? '');
    var tocUrl = pick(r.tocUrl, bookUrl);
    if (tocUrl.isNotEmpty) tocUrl = urlJoin(resp.url, tocUrl);

    final name = pick(r.name, seed?.name ?? '');
    // Author: never cleanAuthor(seed) through a failed rule — garbage detail
    // rules used to wipe a good search-result author via pick() + cleanAuthor.
    final author = _resolveAuthor(
      rule,
      ruleStr: r.author,
      fallback: seed?.author ?? '',
    );
    final intro = pick(r.intro, seed?.intro ?? '');
    final last = pick(r.lastChapter, seed?.lastChapter ?? '');
    final kind = pick(r.kind, seed?.kind ?? '');
    final id = makeBookKey(source.bookSourceUrl, bookUrl);

    return BookInfo(
      id: id,
      name: name,
      author: author,
      coverUrl: cover,
      category: kind,
      description: intro,
      latestChapter: last,
      sourceUrl: source.bookSourceUrl,
      bookUrl: bookUrl,
      originName: source.bookSourceName,
      tocUrl: tocUrl.isEmpty ? bookUrl : tocUrl,
    );
  }

  /// Short reason for a failed stage request (timeout / HTTP / parse).
  String _stageDetail(Object error) {
    if (error is TimeoutException) {
      return '超过 ${sourceTimeout.inSeconds} 秒未响应';
    }
    if (error is DioException) return _dioDetail(error);
    if (error is ArgumentError) return '地址无法解析（可能是 JS 规则未执行）';
    return '请求或解析异常（${Redact.errorType(error)}）';
  }

  /// Detail-page stage test used by the single-source test sheet.
  Future<SourceStageResult> testBookInfo(
    BookSource source,
    String bookUrl,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final info = await bookInfo(source, bookUrl);
      sw.stop();
      if (info.name.isEmpty) {
        return SourceStageResult.failure(
          stage: 'bookInfo',
          elapsedMs: sw.elapsedMilliseconds,
          field: 'name',
          rule: source.ruleBookInfo.name,
          detail: '详情页已返回，但书名规则未匹配',
          bookUrl: info.bookUrl,
          tocUrl: info.tocUrl,
        );
      }
      return SourceStageResult(
        stage: 'bookInfo',
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        detail: '详情解析成功',
        count: 1,
        sample: info.name,
        bookUrl: info.bookUrl,
        tocUrl: info.tocUrl,
      );
    } on SourceStageError catch (e) {
      sw.stop();
      return SourceStageResult.fromError(e, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return SourceStageResult.failure(
        stage: 'bookInfo',
        elapsedMs: sw.elapsedMilliseconds,
        detail: '详情异常（${Redact.errorType(e)}）',
      );
    }
  }

  /// Catalog stage test: reports the failing `chapterList` rule when empty.
  Future<SourceStageResult> testToc(BookSource source, String tocUrl) async {
    final sw = Stopwatch()..start();
    try {
      final chapters = await toc(source, tocUrl);
      sw.stop();
      final readable = chapters.where((c) => !c.isVolume).toList();
      if (readable.isEmpty) {
        return SourceStageResult.failure(
          stage: 'toc',
          elapsedMs: sw.elapsedMilliseconds,
          field: 'chapterList',
          rule: source.ruleToc.chapterList,
          detail: '目录页已返回，但列表规则未匹配到章节',
          tocUrl: tocUrl,
        );
      }
      return SourceStageResult(
        stage: 'toc',
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        detail: '目录解析成功（${readable.length} 章）',
        count: readable.length,
        sample: readable.first.name,
        tocUrl: tocUrl,
        chapterUrl: readable.first.url,
      );
    } on SourceStageError catch (e) {
      sw.stop();
      return SourceStageResult.fromError(e, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return SourceStageResult.failure(
        stage: 'toc',
        elapsedMs: sw.elapsedMilliseconds,
        field: 'chapterList',
        rule: source.ruleToc.chapterList,
        detail: '目录异常（${Redact.errorType(e)}）',
        tocUrl: tocUrl,
      );
    }
  }

  /// Content stage test: reports the failing `content` rule when empty.
  Future<SourceStageResult> testContent(
    BookSource source,
    String chapterUrl,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final text = await content(source, chapterUrl);
      sw.stop();
      if (text.isEmpty) {
        return SourceStageResult.failure(
          stage: 'content',
          elapsedMs: sw.elapsedMilliseconds,
          field: 'content',
          rule: source.ruleContent.content,
          detail: '正文页已返回，但正文规则未匹配到内容',
          chapterUrl: chapterUrl,
        );
      }
      final head = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      return SourceStageResult(
        stage: 'content',
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        detail: '正文解析成功（${text.length} 字）',
        count: text.length,
        sample: head.length > 40 ? head.substring(0, 40) : head,
        chapterUrl: chapterUrl,
      );
    } on SourceStageError catch (e) {
      sw.stop();
      return SourceStageResult.fromError(e, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return SourceStageResult.failure(
        stage: 'content',
        elapsedMs: sw.elapsedMilliseconds,
        field: 'content',
        rule: source.ruleContent.content,
        detail: '正文异常（${Redact.errorType(e)}）',
        chapterUrl: chapterUrl,
      );
    }
  }

  /// Cover for a detail page: rule first, then common selectors, then the
  /// first usable image in the DOM. Returns an absolute URL or ''.
  String _resolveCover(
    BookSource source,
    SourceResponse resp,
    AnalyzeRule rule,
    String seedCover,
  ) {
    var cover = rule.getString(source.ruleBookInfo.coverUrl);
    if (cover.isEmpty || _isPlaceholderCover(cover)) cover = seedCover;
    if (cover.isEmpty || _isPlaceholderCover(cover)) {
      // Common detail-page cover selectors. Lazy-loading themes keep the real
      // URL in data-src / data-original while src holds a shared placeholder.
      for (final fb in const [
        // package:html needs quoted attr values when they contain ':'
        'meta[property="og:image"]@content',
        'meta[name="og:image"]@content',
        'img.cover@data-src',
        'img.cover@data-original',
        '.cover img@data-src',
        '.cover img@data-original',
        '#cover img@data-src',
        '#cover img@data-original',
        'img@data-src',
        'img@data-original',
        'img@data-lazy-src',
        'img.cover@src',
        '.cover img@src',
        '#cover img@src',
        'img@src',
      ]) {
        final c = rule.getString(fb);
        if (c.isNotEmpty && !_isPlaceholderCover(c)) {
          cover = c;
          break;
        }
      }
    }
    if (cover.isEmpty || _isPlaceholderCover(cover)) {
      if (!rule.isJson) {
        final root = rule.doc.documentElement;
        if (root != null) cover = _coverFromElement(root);
      }
    }
    if (cover.isNotEmpty) cover = urlJoin(resp.url, cover);
    if (_isPlaceholderCover(cover)) cover = seedCover;
    if (_isPlaceholderCover(cover)) cover = '';
    return cover;
  }

  /// Fetch only the cover for a list row (detail page + cover rules).
  ///
  /// Used by visible-row enrichment: short budget, silent failure, returns an
  /// absolute URL or an empty string.
  Future<String> fetchCover(
    BookSource source,
    String bookUrl, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final url = AnalyzeUrl.sanitizeUrl(bookUrl, base: source.bookSourceUrl);
    if (url.isEmpty) return '';
    final sw = Stopwatch()..start();
    try {
      final resp = await AnalyzeUrl.fetch(
        source,
        '',
        absoluteUrl: url,
      ).timeout(timeout);
      final body = _applyInitRule(
        resp.body,
        source.ruleBookInfo.init,
        baseUrl: resp.url,
        isJson: resp.isJson,
        jsLib: source.jsLib,
      );
      final rule = AnalyzeRule(
        content: body,
        baseUrl: resp.url,
        isJson: resp.isJson || _looksJson(body),
        jsLib: source.jsLib,
      );
      final cover = _resolveCover(source, resp, rule, '');
      AppLog.d(
        'Cover',
        'enrich "${source.bookSourceName}" url=${Redact.forLog(url)} '
            'hit=${cover.isNotEmpty} ${sw.elapsedMilliseconds}ms',
      );
      return cover;
    } catch (e) {
      AppLog.d(
        'Cover',
        'enrich failed "${source.bookSourceName}" '
            'url=${Redact.forLog(url)} ${Redact.errorType(e)}',
      );
      return '';
    }
  }

  Future<List<SourceChapter>> toc(BookSource source, String tocUrl) async {
    if (tocUrl.isEmpty) {
      throw const SourceStageError(
        stage: 'toc',
        field: 'tocUrl',
        detail: '目录地址为空',
      );
    }
    AppLog.d(
      'Source',
      'toc "${source.bookSourceName}" url=${Redact.forLog(tocUrl)} '
          'chapterList=${source.ruleToc.chapterList}',
    );
    final all = <SourceChapter>[];
    final seen = <String>{};
    var next = tocUrl;
    var pages = 0;
    try {
      while (next.isNotEmpty && pages < maxTocPages) {
        pages++;
        final resp = await AnalyzeUrl.fetch(
          source,
          '',
          absoluteUrl: next,
        ).timeout(sourceTimeout);
        final rule = AnalyzeRule(
          content: resp.body,
          baseUrl: resp.url,
          isJson: resp.isJson,
          jsLib: source.jsLib,
        );
        final listRule = source.ruleToc.chapterList;
        var items = listRule.isEmpty
            ? const <dynamic>[]
            : rule.getList(listRule);
        // Soft fallback for common novel layouts when rule misses.
        if (items.isEmpty && !resp.isJson) {
          for (final fb in const [
            'ul.chapter_list a',
            '.chapter_list a',
            '#list dd a',
            '.listmain dd a',
            '#chapterlist a',
            '.chapterlist a',
            '#chapters a',
          ]) {
            items = rule.getList(fb);
            if (items.isNotEmpty) {
              AppLog.w(
                'RuleMiss',
                'toc rule miss, fallback selector="$fb" hits=${items.length}',
              );
              break;
            }
          }
        }
        var skipped = 0;
        for (final item in items) {
          final nameRule = source.ruleToc.chapterName.isEmpty
              ? 'text'
              : source.ruleToc.chapterName;
          final urlRule = source.ruleToc.chapterUrl.isEmpty
              ? 'href'
              : source.ruleToc.chapterUrl;
          var name = rule.getString(nameRule, scope: item);
          var url = rule.getString(urlRule, scope: item);
          if (item is Element) {
            // Scope may be <li>/<div>; prefer nested <a>.
            final a = item.localName == 'a' ? item : item.querySelector('a');
            if (name.isEmpty) {
              name = (a?.attributes['title'] ?? '').trim();
              if (name.isEmpty) name = (a?.text ?? item.text).trim();
            }
            if (url.isEmpty) {
              url = a?.attributes['href'] ?? item.attributes['href'] ?? '';
            }
          }
          name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (name.isEmpty) {
            skipped++;
            continue;
          }
          // Volume rows have no chapter URL: keep them as grouping headers
          // before the URL checks would drop them.
          final isVol =
              source.ruleToc.isVolume.isNotEmpty &&
              rule.getString(source.ruleToc.isVolume, scope: item).isNotEmpty;
          if (isVol) {
            all.add(
              SourceChapter(
                name: name,
                url: '',
                isVolume: true,
                index: all.length,
              ),
            );
            continue;
          }
          url = urlJoin(resp.url, url.trim());
          if (url.isEmpty) {
            skipped++;
            continue;
          }
          if (!seen.add(url)) continue;
          all.add(
            SourceChapter(
              name: name,
              url: url,
              isVolume: false,
              index: all.length,
            ),
          );
        }
        AppLog.d(
          'Source',
          'toc page=$pages items=${items.length} kept=${all.length} '
              'skipped=$skipped bodyLen=${resp.body.length} '
              'status=${resp.statusCode}',
        );
        var nextUrl = '';
        if (source.ruleToc.nextTocUrl.isNotEmpty) {
          nextUrl = rule.getString(source.ruleToc.nextTocUrl);
          if (nextUrl.isNotEmpty) nextUrl = urlJoin(resp.url, nextUrl);
        }
        if (nextUrl.isEmpty || nextUrl == next || seen.contains(nextUrl)) break;
        next = nextUrl;
      }
      AppLog.i(
        'Source',
        'toc ok "${source.bookSourceName}" chapters=${all.length} pages=$pages',
      );
      return all;
    } on SourceStageError {
      rethrow;
    } catch (e, st) {
      AppLog.e(
        'SourceNet',
        'toc fail "${source.bookSourceName}" '
            'field=chapterList url=${Redact.forLog(tocUrl)}',
        error: e,
        stackTrace: st,
      );
      throw SourceStageError(
        stage: 'toc',
        field: 'chapterList',
        rule: source.ruleToc.chapterList,
        detail: _stageDetail(e),
        cause: e,
      );
    }
  }

  Future<String> content(BookSource source, String chapterUrl) async {
    if (chapterUrl.isEmpty) {
      throw const SourceStageError(
        stage: 'content',
        field: 'chapterUrl',
        detail: '章节地址为空',
      );
    }
    AppLog.d(
      'Source',
      'content "${source.bookSourceName}" url=${Redact.forLog(chapterUrl)}',
    );
    final buf = StringBuffer();
    var next = chapterUrl;
    var pages = 0;
    final seen = <String>{};
    try {
      while (next.isNotEmpty && pages < maxContentPages) {
        if (!seen.add(next)) break;
        pages++;
        final resp = await AnalyzeUrl.fetch(
          source,
          '',
          absoluteUrl: next,
        ).timeout(sourceTimeout);
        final rule = AnalyzeRule(
          content: resp.body,
          baseUrl: resp.url,
          isJson: resp.isJson,
          jsLib: source.jsLib,
        );
        String raw = '';
        final contentRule = source.ruleContent.content;
        final sourceRegex = source.ruleContent.sourceRegex.trim();
        // Prefer sourceRegex (Legado full-page regex extract) when set and
        // content CSS rule is empty or fails.
        if (sourceRegex.isNotEmpty && contentRule.isEmpty) {
          raw = RegexAnalyzer.getString(resp.body, sourceRegex);
        } else if (resp.isJson) {
          raw = rule.getString(contentRule);
        } else {
          if (contentRule.isNotEmpty) {
            raw = rule.getHtmlString(contentRule);
            if (raw.isEmpty) {
              raw = rule.getString(contentRule);
            }
          }
          // Always probe common containers and keep the longest plain text.
          // Many sources return a short partial match (e.g. first <p> only,
          // ~80–150 chars) which is still "valid" but incomplete — the old
          // threshold of 80 skipped fallbacks for those chapters.
          final primaryLen = _plainLen(raw);
          const fallbacks = [
            '.chapter_content_box',
            '#chaptercontent',
            '#content',
            '.content',
            '#BookText',
            '.book-content',
            '.read-content',
            '#chaptercontent p',
            '.chapter_content_box p',
            '#content p',
            'article',
            '.novel_content',
            '#novelcontent',
            '.txtnav',
            '#txtcontent',
          ];
          // Probe when primary is empty/short, or still modest (partial grab).
          final shouldProbe = primaryLen < 500;
          if (shouldProbe) {
            var best = raw;
            var bestLen = primaryLen;
            var bestSel = contentRule.isEmpty ? '(empty)' : contentRule;
            for (final fb in fallbacks) {
              if (fb == contentRule) continue;
              var cand = rule.getHtmlString(fb);
              if (cand.isEmpty) cand = rule.getString(fb);
              final n = _plainLen(cand);
              if (n > bestLen) {
                best = cand;
                bestLen = n;
                bestSel = fb;
              }
            }
            if (bestLen > primaryLen) {
              AppLog.w(
                'RuleMiss',
                'content rule weak/miss, fallback="$bestSel" '
                    'rawLen=$primaryLen fbLen=$bestLen',
              );
              raw = best;
            }
          }
        }
        // sourceRegex as secondary extract when CSS returned little/nothing.
        if (sourceRegex.isNotEmpty && _plainLen(raw) < 80) {
          final viaRe = RegexAnalyzer.getString(resp.body, sourceRegex);
          if (_plainLen(viaRe) > _plainLen(raw)) {
            AppLog.d(
              'Source',
              'content sourceRegex used plainLen=${_plainLen(viaRe)}',
            );
            raw = viaRe;
          }
        }
        if (raw.isEmpty) {
          AppLog.w(
            'RuleMiss',
            'content empty "${source.bookSourceName}" '
                'rule="$contentRule" re="$sourceRegex"',
          );
        }
        final part = finalizeContent(raw, source.ruleContent.replaceRegex);
        AppLog.d(
          'Source',
          'content page=$pages status=${resp.statusCode} '
              'rawLen=${raw.length} plainLen=${part.length}',
        );
        if (part.isNotEmpty) {
          if (buf.isNotEmpty) buf.writeln();
          buf.write(part);
        }
        var nextUrl = '';
        if (source.ruleContent.nextContentUrl.isNotEmpty) {
          nextUrl = rule.getString(source.ruleContent.nextContentUrl);
          if (nextUrl.isNotEmpty) nextUrl = urlJoin(resp.url, nextUrl);
        }
        if (nextUrl.isEmpty || nextUrl == next) break;
        next = nextUrl;
      }
      final text = buf.toString();
      AppLog.i(
        'Source',
        'content ok "${source.bookSourceName}" len=${text.length} pages=$pages',
      );
      return text;
    } on SourceStageError {
      rethrow;
    } catch (e, st) {
      AppLog.e(
        'SourceNet',
        'content fail "${source.bookSourceName}" '
            'field=content url=${Redact.forLog(chapterUrl)}',
        error: e,
        stackTrace: st,
      );
      throw SourceStageError(
        stage: 'content',
        field: 'content',
        rule: source.ruleContent.content,
        detail: _stageDetail(e),
        cause: e,
      );
    }
  }

  /// Apply Legado `ruleBookInfo.init` to narrow/transform page content.
  ///
  /// Supported:
  /// - `@js:` / `<js>` → eval, use string result as new body
  /// - `@regex:` / leading `:` → first capture / match as new body
  /// - CSS / default → first match `innerHtml` (or text) as new body
  /// Empty / failed init leaves [body] unchanged.
  static String _applyInitRule(
    String body,
    String init, {
    required String baseUrl,
    required bool isJson,
    String jsLib = '',
  }) {
    final ruleStr = init.trim();
    if (ruleStr.isEmpty || body.isEmpty) return body;
    try {
      if (JsEngine.needsJs(ruleStr)) {
        final code = JsEngine.extractCode(ruleStr) ?? '';
        if (code.isEmpty) return body;
        final out = JsEngine.instance.eval(
          code,
          result: body,
          baseUrl: baseUrl,
          src: body,
          jsLib: jsLib,
        );
        // cfCheck stubs return original body unchanged — still OK.
        if (out.isNotEmpty) {
          AppLog.d('Source', 'bookInfo.init js applied len=${out.length}');
          return out;
        }
        return body;
      }
      final rule = AnalyzeRule(
        content: body,
        baseUrl: baseUrl,
        isJson: isJson,
        jsLib: jsLib,
      );
      // Regex init
      final trimmed = ruleStr.trim();
      if (trimmed.startsWith('@regex:') ||
          trimmed.startsWith(':') ||
          trimmed.startsWith('@Regex:')) {
        final pat =
            trimmed.startsWith('@regex:') || trimmed.startsWith('@Regex:')
            ? trimmed.substring(trimmed.indexOf(':') + 1)
            : trimmed.substring(1);
        final out = RegexAnalyzer.getString(body, pat);
        if (out.isNotEmpty) {
          AppLog.d('Source', 'bookInfo.init regex applied len=${out.length}');
          return out;
        }
        return body;
      }
      // CSS / JSON path — prefer HTML fragment so child rules still work.
      var out = rule.getHtmlString(ruleStr);
      if (out.isEmpty) out = rule.getString(ruleStr);
      if (out.isNotEmpty) {
        AppLog.d('Source', 'bookInfo.init css/json applied len=${out.length}');
        return out;
      }
      AppLog.w('RuleMiss', 'bookInfo.init produced empty rule="$ruleStr"');
    } catch (e) {
      AppLog.w('RuleMiss', 'bookInfo.init error rule="$ruleStr"', error: e);
    }
    return body;
  }

  static bool _looksJson(String s) {
    final t = s.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  /// Cheap length of text after stripping tags (for fallback ranking).
  static int _plainLen(String htmlOrText) {
    if (htmlOrText.isEmpty) return 0;
    return htmlOrText
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .length;
  }

  /// Attributes that hold a cover URL, ordered by reliability. `src` is last
  /// because lazy-loading themes put a shared placeholder there.
  static const List<String> _coverAttrs = [
    'data-src',
    'data-original',
    'data-lazy-src',
    'data-lazy',
    'data-echo',
    'data-url',
    'src',
  ];

  static final RegExp _cssUrl = RegExp(
    r'''url\(\s*['"]?([^'")]+)['"]?\s*\)''',
    caseSensitive: false,
  );

  /// Pull the first usable cover URL from an item / page element.
  static String _coverFromElement(Element root) {
    final images = <Element>[
      if (root.localName == 'img') root,
      ...root.querySelectorAll('img'),
    ];
    for (final image in images) {
      for (final attr in _coverAttrs) {
        final raw = image.attributes[attr]?.trim() ?? '';
        if (raw.isEmpty || raw.startsWith('data:')) continue;
        final url = _firstUrl(raw);
        if (url.isNotEmpty && !_isPlaceholderCover(url)) return url;
      }
      final style = _cssBackground(image.attributes['style'] ?? '');
      if (style.isNotEmpty && !_isPlaceholderCover(style)) return style;
      final srcset = _firstSrcset(image.attributes['srcset'] ?? '');
      if (srcset.isNotEmpty && !_isPlaceholderCover(srcset)) return srcset;
    }
    // <picture><source srcset="...">
    for (final source in root.querySelectorAll('source')) {
      final srcset = _firstSrcset(source.attributes['srcset'] ?? '');
      if (srcset.isNotEmpty && !_isPlaceholderCover(srcset)) return srcset;
    }
    return '';
  }

  /// Some themes stuff a whole `srcset` into `data-src`.
  static String _firstUrl(String raw) {
    final first = raw.trim().split(',').first.trim();
    if (!first.contains(RegExp(r'\s'))) return first;
    return first.split(RegExp(r'\s+')).first;
  }

  static String _firstSrcset(String raw) {
    for (final part in raw.split(',')) {
      final candidate = part.trim().split(RegExp(r'\s+')).first;
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  static String _cssBackground(String style) {
    return _cssUrl.firstMatch(style)?.group(1)?.trim() ?? '';
  }

  static bool _isPlaceholderCover(String url) {
    if (url.isEmpty) return true;
    final u = url.toLowerCase();
    return u.contains('loading.jpg') ||
        u.contains('loading.png') ||
        u.contains('placeholder') ||
        u.contains('default_cover') ||
        u.contains('nocover') ||
        u.contains('nopic') ||
        u.contains('noimg') ||
        u.contains('no-cover') ||
        u.endsWith('/lazy.png');
  }

  /// Resolve author from rule + soft fallbacks. Never wipe a good [fallback]
  /// (e.g. search seed) when the detail rule returns unusable text.
  static String _resolveAuthor(
    AnalyzeRule rule, {
    String ruleStr = '',
    dynamic scope,
    String fallback = '',
  }) {
    if (ruleStr.isNotEmpty) {
      final cleaned = cleanAuthor(rule.getString(ruleStr, scope: scope));
      if (cleaned.isNotEmpty) return cleaned;
    }

    // Soft selectors — many sources omit / misconfigure author rules.
    final selectors = scope is Element
        ? const [
            '.author@text',
            'span.author@text',
            'p.author@text',
            'a.author@text',
            '.writer@text',
            '.book_author@text',
            '.authorName@text',
            '.s@text',
            'p.meta@text',
            '.btm@text',
            '.bookinfo@text',
            '.info@text',
          ]
        : const [
            'meta[property="og:novel:author"]@content',
            'meta[name="author"]@content',
            'meta[property="og:author"]@content',
            'meta[property="og:novel:author"]@content',
            '#info p@text',
            '.info .author@text',
            '.book-info .author@text',
            '.detail .author@text',
            '.author@text',
            'span.author@text',
            'p.author@text',
            'a.author@text',
            '.writer@text',
            '#bookinfo .author@text',
            '.bookinfo@text',
          ];

    for (final sel in selectors) {
      final cleaned = cleanAuthor(rule.getString(sel, scope: scope));
      if (cleaned.isNotEmpty) return cleaned;
    }

    // Last resort: whole card / page text may still contain "作者：xxx".
    if (scope is Element) {
      final cleaned = cleanAuthor(scope.text);
      if (cleaned.isNotEmpty) return cleaned;
    }

    return cleanAuthor(fallback);
  }
}

class _ParsedBookList {
  const _ParsedBookList(
    this.books, {
    this.rawItems = 0,
    this.dropped = 0,
  });

  final List<SearchBook> books;
  final int rawItems;
  final int dropped;
}

class _SearchRun {
  const _SearchRun({
    required this.books,
    required this.rawItems,
    required this.dropped,
    required this.requestUrl,
    required this.bodyLength,
    required this.keyInBody,
    required this.httpStatus,
    required this.listRule,
  });

  final List<SearchBook> books;
  final int rawItems;
  final int dropped;
  final String requestUrl;
  final int bodyLength;
  final bool keyInBody;
  final int httpStatus;
  final String listRule;
}
