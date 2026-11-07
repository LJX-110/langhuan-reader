import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/core/net/native_cookie_cache.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_diagnostics.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';

/// 引擎列表页结果：条目 + 翻页游标。
class BookListResult {
  const BookListResult({
    required this.hits,
    this.hasNextPage = false,
    this.nextPageUrl = '',
  });

  final List<SearchBook> hits;
  final bool hasNextPage;
  final String nextPageUrl;
}

/// 阅读内核的唯一入口 —— Legado 裁剪集（AAR）经 `langhuan/engine` 通道调用。
///
/// 设计约定（2026-11-06 起）：**全应用只有这一套书源引擎**。
/// 没有第二引擎、没有兜底、没有开关；任何阶段失败都以 [SourceStageError]
/// 呈现（搜索以带归因的 [SourceSearchReport] 呈现），由界面重试 / 换源。
class SourceEngine {
  SourceEngine._();

  static final SourceEngine instance = SourceEngine._();

  static const String _tag = 'Engine';
  static const MethodChannel _channel = MethodChannel('langhuan/engine');
  static int _requestSeq = 0;

  /// 列表类调用（搜索 / 发现 / 详情 / 目录）的单请求上限。
  static const Duration _listTimeout = Duration(seconds: 20);

  /// 正文可跨多页拼合，给更宽的上限。
  static const Duration _contentTimeout = Duration(seconds: 60);

  // ── 搜索 / 发现 ────────────────────────────────────────────────────────

  /// 单源搜索 + 诊断报告。永不抛出：断链 / 规则 / 网络失败都归因到
  /// [SourceSearchReport.issue]，搜索界面据此展示状态。
  Future<SourceSearchReport> searchWithReport(
    BookSource source,
    String key,
    int page, {
    String? nextPageUrl,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final resp = await _call(
        'search',
        {
          'source': _requireSourceJson(source),
          'keyword': key,
          'page': page,
          'nextPageUrl': nextPageUrl ?? '',
        },
        stage: 'search',
        field: 'searchUrl',
        rule: source.searchUrl,
      );
      sw.stop();
      final result = _bookList(resp, source);
      _rememberCookie(source.bookSourceUrl);
      return SourceSearchReport(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        keyword: key,
        page: page,
        issue: result.hits.isEmpty
            ? SourceSearchIssue.noResult
            : SourceSearchIssue.none,
        hits: result.hits,
        elapsedMs: sw.elapsedMilliseconds,
        hasNextPage: result.hasNextPage,
        nextPageUrl: result.nextPageUrl,
      );
    } catch (e) {
      sw.stop();
      final detail = _detailOf(e);
      return SourceSearchReport(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        keyword: key,
        page: page,
        issue: _issueFrom(detail),
        elapsedMs: sw.elapsedMilliseconds,
        detail: detail,
      );
    }
  }

  /// 发现列表（exploreUrl 分类）。失败抛 [SourceStageError]（stage: explore）。
  Future<BookListResult> explorePage(
    BookSource source,
    String url, {
    int page = 1,
    String? nextPageUrl,
  }) async {
    if (url.trim().isEmpty) {
      return const BookListResult(hits: []);
    }
    final resp = await _call(
      'explore',
      {
        'source': _requireSourceJson(source),
        'key': url,
        'page': page,
        'nextPageUrl': nextPageUrl ?? '',
      },
      stage: 'explore',
      field: 'exploreUrl',
      rule: source.exploreUrl,
    );
    _rememberCookie(source.bookSourceUrl);
    return _bookList(resp, source);
  }

  // ── 详情 / 目录 / 正文 ─────────────────────────────────────────────────

  /// 详情。失败抛 [SourceStageError]（stage: bookInfo）。
  Future<BookInfo> bookInfo(
    BookSource source,
    String bookUrl, {
    SearchBook? seed,
  }) async {
    final resp = await _call(
      'bookInfo',
      {
        'source': _requireSourceJson(source),
        'book': jsonEncode(
          buildBookJson(
            bookUrl: bookUrl,
            tocUrl: '',
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: seed?.name ?? '',
            author: seed?.author ?? '',
            kind: seed?.kind ?? '',
            intro: seed?.intro ?? '',
            coverUrl: seed?.coverUrl ?? '',
            latestChapterTitle: seed?.lastChapter ?? '',
            wordCount: seed?.wordCount ?? '',
          ),
        ),
      },
      stage: 'bookInfo',
      field: 'bookUrl',
      rule: source.ruleBookInfo.name,
    );
    final rawBook = resp['book'];
    final map = rawBook is String ? _decodeMap(rawBook) : null;
    if (map == null) {
      throw const SourceStageError(
        stage: 'bookInfo',
        field: 'bookUrl',
        detail: '详情回包格式异常',
      );
    }
    final resolvedBookUrl = (map['bookUrl'] ?? '').toString();
    AppLog.i(_tag, 'bookInfo ok "${source.bookSourceName}"');
    _rememberCookie(resolvedBookUrl.isEmpty ? bookUrl : resolvedBookUrl);
    return BookInfo(
      name: (map['name'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      category: (map['kind'] ?? '').toString(),
      description: (map['intro'] ?? '').toString(),
      latestChapter: (map['latestChapterTitle'] ?? '').toString(),
      sourceUrl: source.bookSourceUrl,
      originName: source.bookSourceName,
      bookUrl: resolvedBookUrl.isEmpty ? bookUrl : resolvedBookUrl,
      tocUrl: (map['tocUrl'] ?? '').toString(),
    );
  }

  /// 目录。失败抛 [SourceStageError]（stage: toc）。
  Future<List<SourceChapter>> toc(
    BookSource source,
    String tocUrl, {
    String bookUrl = '',
    String bookName = '',
  }) async {
    final baseBookUrl = bookUrl.isEmpty ? tocUrl : bookUrl;
    final resp = await _call(
      'toc',
      {
        'source': _requireSourceJson(source),
        'book': jsonEncode(
          buildBookJson(
            bookUrl: baseBookUrl,
            tocUrl: tocUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: bookName,
          ),
        ),
      },
      stage: 'toc',
      field: 'chapterList',
      rule: source.ruleToc.chapterList,
    );
    final rawChapters = resp['chapters'];
    final list = rawChapters is String ? _decodeList(rawChapters) : null;
    if (list == null) {
      throw const SourceStageError(
        stage: 'toc',
        field: 'chapterList',
        detail: '目录回包格式异常',
      );
    }
    final out = <SourceChapter>[];
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m is! Map) continue;
      final isVolume = m['isVolume'] == true;
      final url = (m['url'] ?? '').toString();
      if (url.isEmpty && !isVolume) continue;
      out.add(
        SourceChapter(
          name: (m['title'] ?? '').toString(),
          url: url,
          isVolume: isVolume,
          index: (m['index'] is num) ? (m['index'] as num).toInt() : i,
          info: (m['tag'] ?? '').toString(),
        ),
      );
    }
    AppLog.i(_tag, 'toc ok "${source.bookSourceName}" chapters=${out.length}');
    _rememberCookie(tocUrl);
    return out;
  }

  /// 正文（多页自动拼合，见引擎侧 BookContent 边界闸）。
  /// 失败抛 [SourceStageError]（stage: content）。
  Future<String> content(
    BookSource source,
    String chapterUrl, {
    String bookUrl = '',
    String bookName = '',
    String chapterTitle = '',
    int chapterIndex = 0,
    String nextChapterUrl = '',
    int totalChapterNum = 0,
  }) async {
    final baseBookUrl = bookUrl.isEmpty ? chapterUrl : bookUrl;
    final resp = await _call(
      'content',
      {
        'source': _requireSourceJson(source),
        'book': jsonEncode(
          buildBookJson(
            bookUrl: baseBookUrl,
            tocUrl: '',
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: bookName,
            totalChapterNum: totalChapterNum,
          ),
        ),
        'chapter': jsonEncode({
          'url': chapterUrl,
          'title': chapterTitle,
          'index': chapterIndex,
          'bookUrl': baseBookUrl,
        }),
        'nextChapterUrl': nextChapterUrl,
      },
      stage: 'content',
      field: 'content',
      rule: source.ruleContent.content,
      timeout: _contentTimeout,
    );
    final text = (resp['content'] ?? '').toString();
    if (text.isEmpty) {
      throw const SourceStageError(
        stage: 'content',
        field: 'content',
        detail: '正文页已返回，但正文规则未匹配到内容',
      );
    }
    AppLog.i(_tag, 'content ok len=${text.length}');
    _rememberCookie(chapterUrl);
    return text;
  }

  // ── 正文简繁转换（阅读内核的词典） ─────────────────────────────────────

  /// 简体 ↔ 繁体；失败抛 [SourceStageError]（stage: convert）。
  Future<String> convertChinese(
    String text, {
    required bool traditional,
  }) async {
    if (text.isEmpty) return text;
    final resp = await _call(
      'convertChinese',
      {'text': text, 'traditional': traditional},
      stage: 'convert',
      field: 'text',
    );
    return (resp['text'] ?? text).toString();
  }

  // ── Cookie（统一由阅读内核的 SharedCookieStore 持有） ───────────────────

  /// 当前 URL 的 Cookie；失败返回空串。成功后同步更新 [NativeCookieCache]。
  Future<String> cookieHeader(String url) async {
    try {
      final resp = await _call(
        'cookie',
        {'url': url},
        stage: 'cookie',
        field: 'url',
        rule: '',
      );
      final cookie = (resp['cookie'] ?? '').toString();
      NativeCookieCache.put(url, cookie);
      return cookie;
    } catch (_) {
      return '';
    }
  }

  /// 引擎私有缓存字节数（不含登录态）。
  Future<int> engineCacheBytes() async {
    try {
      final resp = await _call(
        'cacheStats',
        const {},
        stage: 'cache',
        field: 'cache',
        rule: '',
      );
      final bytes = resp['bytes'];
      return bytes is num ? bytes.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// 清除引擎私有缓存（filesDir/legado + cacheDao + 内存源变量）。
  Future<void> clearEngineCache() async {
    try {
      await _call(
        'clearEngineCache',
        const {},
        stage: 'cache',
        field: 'cache',
        rule: '',
      );
    } catch (_) {
      // 清理失败不阻塞 UI。
    }
  }

  /// 清除全部登录态（持久 Cookie + 内存热层 + Dart 缓存）。
  Future<void> clearCookies() async {
    try {
      await _call(
        'clearCookies',
        const {},
        stage: 'cookie',
        field: 'url',
        rule: '',
      );
    } catch (_) {
      // 清理失败不阻塞 UI；下次请求仍会走引擎。
    }
    NativeCookieCache.clear();
  }

  void _rememberCookie(String url) {
    if (url.isEmpty) return;
    unawaited(cookieHeader(url));
  }

  /// 详情页封面补抓（供书架 / 列表补封面）。失败返回 ''，不抛。
  Future<String> fetchCover(BookSource source, String bookUrl) async {
    try {
      final info = await bookInfo(source, bookUrl);
      return info.coverUrl;
    } catch (e) {
      AppLog.w(_tag, 'fetchCover failed "${source.bookSourceName}"', error: e);
      return '';
    }
  }

  // ── 单源阶段测试（书源体检 / 测试面板） ────────────────────────────────

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

  Future<SourceStageResult> testContent(
    BookSource source,
    String chapterUrl,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final text = await content(source, chapterUrl);
      sw.stop();
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

  // ── 通道与解析 ─────────────────────────────────────────────────────────

  /// 书源 JSON：直接用入库时保存的 Legado 原文（导入 / 编辑器都保真）。
  static String? sourceJson(BookSource source) =>
      source.rawJson.trim().isEmpty ? null : source.rawJson;

  static String _requireSourceJson(BookSource source) {
    final raw = sourceJson(source);
    if (raw == null) {
      throw const SourceStageError(
        stage: 'source',
        field: 'rawJson',
        detail: '书源规则缺失，请重新导入或编辑保存',
      );
    }
    return raw;
  }

  /// 构造 Kotlin `Book` 可解码的 JSON（字段名对齐实体序列化名；
  /// 空值给 null，Kotlin 侧全部有默认值）。
  @visibleForTesting
  static Map<String, dynamic> buildBookJson({
    required String bookUrl,
    required String tocUrl,
    required String origin,
    required String originName,
    String name = '',
    String author = '',
    String kind = '',
    String intro = '',
    String coverUrl = '',
    String latestChapterTitle = '',
    String wordCount = '',
    int totalChapterNum = 0,
  }) => {
    'bookUrl': bookUrl,
    'tocUrl': tocUrl,
    'origin': origin,
    'originName': originName,
    'name': name,
    'author': author,
    'kind': kind.isEmpty ? null : kind,
    'intro': intro.isEmpty ? null : intro,
    'coverUrl': coverUrl.isEmpty ? null : coverUrl,
    'latestChapterTitle': latestChapterTitle.isEmpty
        ? null
        : latestChapterTitle,
    'wordCount': wordCount.isEmpty ? null : wordCount,
    'totalChapterNum': totalChapterNum,
  };

  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic> args, {
    required String stage,
    required String field,
    String rule = '',
    Duration timeout = _listTimeout,
  }) async {
    final requestId = '${_requestSeq++}';
    final payload = <String, dynamic>{...args, 'requestId': requestId};
    final String? raw;
    try {
      raw = await _channel
          .invokeMethod<String>(method, payload)
          .timeout(timeout);
    } on TimeoutException {
      unawaited(_cancel(requestId));
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: '请求超时（${timeout.inSeconds}s），已取消',
      );
    } on PlatformException catch (e) {
      unawaited(_cancel(requestId));
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: _platformDetail(e),
      );
    } on MissingPluginException {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: '阅读内核不可用（通道未接线）',
      );
    } catch (e) {
      unawaited(_cancel(requestId));
      rethrow;
    }
    Map<String, dynamic>? decoded;
    try {
      final v = raw == null ? null : jsonDecode(raw);
      decoded = v is Map<String, dynamic> ? v : null;
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: '引擎回包格式异常',
      );
    }
    if (decoded['ok'] != true) {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: (decoded['error'] ?? '引擎调用失败').toString(),
      );
    }
    return decoded;
  }

  /// 结构化错误码 → 用户可行动的短文案（细节只进日志）。
  static String _platformDetail(PlatformException e) => switch (e.code) {
    'engine_busy' => '引擎繁忙，请稍后重试',
    'engine_cancelled' => '请求已取消',
    'engine_timeout' => '请求超时，已取消',
    'engine_network' => '网络不可用，检查网络或换个书源',
    'bad_args' => '请求参数不完整',
    _ => e.message ?? '引擎调用失败',
  };

  static Future<void> _cancel(String requestId) async {
    try {
      await _channel.invokeMethod<bool>('cancel', {'requestId': requestId});
    } catch (_) {
      // Best effort: timeout already reported to the caller.
    }
  }

  BookListResult _bookList(Map<String, dynamic> resp, BookSource source) {
    final raw = resp['hits'];
    final hits = <SearchBook>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final bookUrl = (item['bookUrl'] ?? '').toString().trim();
        if (bookUrl.isEmpty) continue;
        hits.add(
          SearchBook(
            name: (item['name'] ?? '').toString(),
            author: (item['author'] ?? '').toString(),
            kind: (item['kind'] ?? '').toString(),
            wordCount: (item['wordCount'] ?? '').toString(),
            lastChapter: (item['lastChapter'] ?? '').toString(),
            intro: (item['intro'] ?? '').toString(),
            coverUrl: (item['coverUrl'] ?? '').toString(),
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
      }
    }
    return BookListResult(
      hits: hits,
      hasNextPage: resp['hasNextPage'] == true,
      nextPageUrl: (resp['nextPageUrl'] ?? '').toString(),
    );
  }

  static String _detailOf(Object e) {
    if (e is SourceStageError) return e.detail;
    return Redact.userMessage(e);
  }

  /// 失败文本 → 搜索诊断归因（粗粒度关键词分类，够 UI 给出可行动提示）。
  static SourceSearchIssue _issueFrom(String detail) {
    final d = detail.toLowerCase();
    if (detail.contains('超时') || d.contains('timeout')) {
      return SourceSearchIssue.timeout;
    }
    if (detail.contains('无法连接') ||
        detail.contains('连接失败') ||
        d.contains('connect') ||
        d.contains('socket') ||
        d.contains('resolve') ||
        d.contains('tls') ||
        d.contains('certificate')) {
      return SourceSearchIssue.network;
    }
    if (detail.contains('未接线') || detail.contains('格式异常')) {
      return SourceSearchIssue.unknown;
    }
    if (d.contains('url') || detail.contains('规则') || detail.contains('不能为空')) {
      return SourceSearchIssue.incompatibleRule;
    }
    return SourceSearchIssue.parse;
  }

  static Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  static List<dynamic>? _decodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) return v;
    } catch (_) {}
    return null;
  }
}
