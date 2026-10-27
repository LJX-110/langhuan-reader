import 'dart:async';

import 'package:dio/dio.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/discover/cover_enricher.dart';
import 'package:langhuan/features/sources/source_model.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

/// Bottom-tab discovery: book-source exploreUrl kinds + paginated book list.
class ExploreModel with ChangeNotifier {
  final BookSourceEngine _engine = BookSourceEngine();
  late final CoverEnricher _covers = CoverEnricher(fetch: _fetchCover);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<BookSource> exploreSources = [];
  BookSource? activeSource;
  List<ExploreKind> kinds = [];
  ExploreKind? activeKind;

  List<SearchItem> books = [];
  bool loading = false;
  bool bootstrapped = false;

  /// A reload requested while another one is in flight (e.g. import finishes
  /// during the initial discovery load).
  bool _reloadQueued = false;

  /// True after a page returns empty results — stops further load-more.
  bool noMore = false;
  int page = 1;
  String? error;

  Future<void> ensureLoaded() async {
    if (bootstrapped && exploreSources.isNotEmpty) return;
    await reloadSources();
  }

  Future<void> reloadSources() async {
    if (loading) {
      _reloadQueued = true;
      return;
    }
    loading = true;
    error = null;
    noMore = false;
    notifyListeners();
    try {
      final model = SourceModel();
      final all = await model.enabledSources();
      exploreSources = all.where((s) => s.canExplore).toList()
        ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

      if (exploreSources.isEmpty) {
        activeSource = null;
        kinds = [];
        activeKind = null;
        books = [];
        error =
            '暂无可用发现书源。只有启用且带 exploreUrl 的书源会出现在这里；'
            '仅搜索源请用书架搜索。';
        return;
      }

      // Keep previous selection if still present; hydrate rules for engine.
      final prevUrl = activeSource?.bookSourceUrl;
      final meta = exploreSources.firstWhere(
        (s) => s.bookSourceUrl == prevUrl,
        orElse: () => exploreSources.first,
      );
      activeSource = await model.findByUrl(meta.bookSourceUrl) ?? meta;
      _applyKinds();
      bootstrapped = true;
      await loadBooks(refresh: true);
    } catch (e) {
      error = '加载发现失败：${Redact.userMessage(e)}';
    } finally {
      loading = false;
      notifyListeners();
      if (_reloadQueued) {
        _reloadQueued = false;
        unawaited(reloadSources());
      }
    }
  }

  void _applyKinds() {
    final src = activeSource;
    if (src == null) {
      kinds = [];
      activeKind = null;
      return;
    }
    kinds = parseExploreKinds(src.exploreUrl);
    if (kinds.isEmpty) {
      kinds = [ExploreKind(title: '全部', url: src.exploreUrl)];
    }
    final prev = activeKind?.title;
    activeKind = kinds.firstWhere(
      (k) => k.title == prev,
      orElse: () => kinds.first,
    );
  }

  Future<void> selectSource(BookSource source) async {
    if (activeSource?.bookSourceUrl == source.bookSourceUrl) return;
    activeSource =
        await SourceModel().findByUrl(source.bookSourceUrl) ?? source;
    _applyKinds();
    await loadBooks(refresh: true);
  }

  Future<void> selectKind(ExploreKind kind) async {
    if (activeKind?.title == kind.title && activeKind?.url == kind.url) return;
    activeKind = kind;
    await loadBooks(refresh: true);
  }

  Future<void> loadBooks({bool refresh = false}) async {
    final src = activeSource;
    final kind = activeKind;
    if (src == null || kind == null) return;

    if (refresh) {
      page = 1;
      books = [];
      noMore = false;
    }

    loading = true;
    error = null;
    notifyListeners();
    try {
      final hits = await _engine.explore(src, kind.url, page: page);
      if (hits.isEmpty) {
        if (page == 1) {
          error = '该分类没有解析到内容，可能书源失效或站点拦截';
        }
        noMore = true;
      } else {
        final added = <SearchItem>[];
        for (final h in hits) {
          final item = _toItem(h);
          books.add(item);
          added.add(item);
        }
        unawaited(_enrich(added));
      }
    } catch (e) {
      AppLog.w('Explore', 'load books failed', error: e);
      if (e is TimeoutException) {
        error = '加载超时，请重试或换一个书源';
      } else if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.badCertificate)) {
        // Sites that reset the connection are not a rule problem.
        error = '站点无法连接（可能被拦截），换一个书源试试';
      } else {
        error = '加载失败，请重试或换一个书源';
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || noMore) return;
    page += 1;
    await loadBooks(refresh: false);
  }

  SearchItem _toItem(SearchBook h) {
    final id = makeBookKey(h.sourceUrl, h.bookUrl);
    return SearchItem(
      id: id,
      name: h.name,
      author: h.author,
      coverUrl: h.coverUrl,
      description: h.intro,
      latestChapter: h.lastChapter,
      category: h.kind,
      sourceUrl: h.sourceUrl,
      bookUrl: h.bookUrl,
      sourceName: h.sourceName,
    );
  }

  /// Fill missing covers for the rows just added (visible first screen).
  Future<void> _enrich(List<SearchItem> items) => _covers.enrich(
    items,
    limit: 8,
    onUpdated: () {
      if (!_disposed) notifyListeners();
    },
  );

  Future<String> _fetchCover(SearchItem item) async {
    BookSource? src = activeSource;
    if (src == null || src.bookSourceUrl != item.sourceUrl) {
      src = await SourceModel().findByUrl(item.sourceUrl);
    }
    if (src == null) return '';
    return _engine.fetchCover(src, item.bookUrl);
  }

  Future<BookInfo?> openDetail(SearchItem item) async {
    final resolved = AnalyzeUrl.sanitizeUrl(item.bookUrl, base: item.sourceUrl);
    if (item.sourceUrl.isEmpty || resolved.isEmpty) {
      BotToast.showText(text: '该书详情地址无效，可能书源规则不完整');
      return null;
    }
    final src = await SourceModel().findByUrl(item.sourceUrl);
    if (src == null) {
      BotToast.showText(text: '书源不存在：${item.sourceName}');
      return null;
    }
    try {
      final seed = SearchBook(
        name: item.name,
        author: item.author,
        intro: item.description,
        coverUrl: item.coverUrl,
        lastChapter: item.latestChapter,
        kind: item.category,
        bookUrl: resolved,
        sourceUrl: item.sourceUrl,
        sourceName: item.sourceName,
      );
      return await _engine.bookInfo(src, resolved, seed: seed);
    } catch (e) {
      BotToast.showText(text: '获取详情失败，请稍后重试');
      return null;
    }
  }
}
