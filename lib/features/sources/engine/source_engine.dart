import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_diagnostics.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';

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

  /// 列表类调用（搜索 / 发现 / 详情 / 目录）的单请求上限。
  static const Duration _listTimeout = Duration(seconds: 20);

  /// 正文可跨多页拼合，给更宽的上限。
  static const Duration _contentTimeout = Duration(seconds: 60);

  // ── 探测 ───────────────────────────────────────────────────────────────

  static bool? _pinged;

  /// 通道是否可用（未接线 / 旧包装返回 false）。仅用于诊断，不做兜底分流。
  static Future<bool> ping() async {
    if (_pinged != null) return _pinged!;
    try {
      _pinged = await _channel.invokeMethod<bool>('ping') == true;
    } catch (_) {
      _pinged = false;
    }
    return _pinged!;
  }

  // ── 搜索 / 发现 ────────────────────────────────────────────────────────

  /// 单源搜索 + 诊断报告。永不抛出：断链 / 规则 / 网络失败都归因到
  /// [SourceSearchReport.issue]，搜索界面据此展示状态。
  Future<SourceSearchReport> searchWithReport(
    BookSource source,
    String key,
    int page,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final resp = await _call(
        'search',
        {'source': sourceJson(source), 'keyword': key, 'page': page},
        stage: 'search',
        field: 'searchUrl',
        rule: source.searchUrl,
      );
      sw.stop();
      final hits = _hits(resp, source);
      return SourceSearchReport(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        keyword: key,
        page: page,
        issue: hits.isEmpty ? SourceSearchIssue.noResult : SourceSearchIssue.none,
        hits: hits,
        elapsedMs: sw.elapsedMilliseconds,
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
  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
    String? nextPageUrl,
  }) async {
    if (url.trim().isEmpty) return const [];
    final resp = await _call(
      'explore',
      {
        'source': sourceJson(source),
        'key': url,
        'page': page,
        'nextPageUrl': nextPageUrl ?? '',
      },
      stage: 'explore',
      field: 'exploreUrl',
      rule: source.exploreUrl,
    );
    return _hits(resp, source);
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
        'source': sourceJson(source),
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
        'source': sourceJson(source),
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
        'source': sourceJson(source),
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
    return text;
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
    'latestChapterTitle': latestChapterTitle.isEmpty ? null : latestChapterTitle,
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
    final String? raw;
    try {
      raw = await _channel.invokeMethod<String>(method, args).timeout(timeout);
    } on PlatformException catch (e) {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: e.message ?? '引擎调用失败',
      );
    } on MissingPluginException {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: '阅读内核不可用（通道未接线）',
      );
    } on TimeoutException {
      throw SourceStageError(
        stage: stage,
        field: field,
        rule: rule,
        detail: '请求超时（${timeout.inSeconds}s）',
      );
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

  List<SearchBook> _hits(Map<String, dynamic> resp, BookSource source) {
    final raw = resp['hits'];
    if (raw is! List) return const [];
    final out = <SearchBook>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final bookUrl = (item['bookUrl'] ?? '').toString().trim();
      if (bookUrl.isEmpty) continue;
      out.add(
        SearchBook(
          name: (item['name'] ?? '').toString(),
          author: (item['author'] ?? '').toString(),
          kind: (item['kind'] ?? '').toString(),
          lastChapter: (item['lastChapter'] ?? '').toString(),
          intro: (item['intro'] ?? '').toString(),
          coverUrl: (item['coverUrl'] ?? '').toString(),
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        ),
      );
    }
    return out;
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
    if (d.contains('url') ||
        detail.contains('规则') ||
        detail.contains('不能为空')) {
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
