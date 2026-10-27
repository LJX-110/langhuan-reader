import 'dart:async';
import 'package:langhuan/core/utils/redact.dart';

import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/discover/cover_enricher.dart';
import 'package:langhuan/features/search/search_keyword_cache.dart';
import 'package:langhuan/features/search/search_result_ranker.dart';
import 'package:langhuan/features/sources/model/source_groups.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/search/search_result_deduper.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

/// One book after duplicate hits from different sources are folded together.
class SearchGroup {
  SearchGroup(this.item);

  final SearchItem item;
  final Set<String> sourceNames = <String>{};
  final Set<String> sourceUrls = <String>{};

  int get sourceCount => sourceUrls.length;
}

class SearchModel with ChangeNotifier {
  List<String> searchHistory = [];
  BuildContext? context;
  bool showResult = false;
  List<SearchItem> bks = [];
  bool loading = false;

  late final CoverEnricher _covers = CoverEnricher(fetch: _fetchCover);
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _softTimer?.cancel();
    super.dispose();
  }

  /// True after a page returns empty results — stops further load-more.
  bool noMore = false;

  /// How many searchable sources were scanned in the current page sweep.
  int searchedSources = 0;

  /// Total searchable sources for the current page sweep.
  int totalSources = 0;

  /// Sources that timed out or failed in the current sweep.
  int failedSources = 0;

  /// Names of failed sources, in completion order (for actionable messages).
  final List<String> failedSourceNames = [];

  /// Latest per-source report for the current sweep, in completion order.
  final List<SourceSearchReport> reports = [];

  /// Sources with an in-flight single-source retry.
  final Set<String> retryingSources = {};

  /// First-screen window: results appear as sources answer; once this elapses
  /// the UI offers 「停止等待」 instead of pretending the sweep is instant.
  static const Duration firstScreenWindow = Duration(seconds: 20);

  /// True once [firstScreenWindow] elapsed while a sweep is still running.
  bool softTimeoutElapsed = false;

  Timer? _softTimer;

  List<SourceSearchReport> get failures =>
      reports.where((r) => r.failed).toList(growable: false);

  bool get allSourcesFailed =>
      totalSources > 0 && failedSources >= totalSources;

  /// Empty-state explanation: no hits vs all sources failed vs partial outage.
  String get emptyHint {
    if (failedSources <= 0) return '换个书名、作者或关键词再试。';
    if (allSourcesFailed) {
      final names = failedSourceNames.take(3).join('、');
      final suffix = failedSourceNames.length > 3 ? ' 等' : '';
      final breakdown = _failureBreakdown();
      final reason = breakdown.isEmpty ? '' : '：$breakdown';
      return names.isEmpty
          ? '全部 $totalSources 个书源请求失败$reason，'
                '请检查网络或书源配置后重试。'
          : '全部 $totalSources 个书源请求失败（$names$suffix）$reason，'
                '请检查网络或书源配置后重试。';
    }
    return '$failedSources 个书源请求失败，结果可能不完整。';
  }

  String _failureBreakdown() {
    final counts = <SourceSearchIssue, int>{};
    for (final report in reports.where((r) => r.failed)) {
      counts[report.issue] = (counts[report.issue] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    return counts.entries
        .map((e) => '${e.key.label} ${e.value}')
        .join('、');
  }

  String historyKey = "";
  int page = 1;
  var word = "";
  TextEditingController? controller;

  final BookSourceEngine _engine = BookSourceEngine();
  final SourceRepository _sources = SourceRepository.instance;

  /// Concurrent source search pool size (slow networks do better at 6 than
  /// at 10; a future settings row can expose this).
  static const int defaultSourceConcurrency = 6;
  int sourceConcurrency = defaultSourceConcurrency;

  final SearchKeywordCache _keywordCache = SearchKeywordCache();

  /// True while the shown hits came from the keyword cache and a background
  /// refresh is still running.
  bool fromCache = false;

  /// Group scope for the sweep ('' = all sources).
  String groupFilter = '';

  /// Groups available among the enabled sources (for the filter chips).
  List<String> groupOptions = const [];

  /// Bumps on each new search/loadMore so stale chunks are discarded.
  int _searchGen = 0;

  /// Stable ids already folded into [bks]; a page that only repeats them means
  /// the source ignored `{{page}}` and further load-more would loop forever.
  final SearchResultDeduper _deduper = SearchResultDeduper();

  /// Search hits folded by book name + author, preserving first hit order.
  List<SearchGroup> get groups {
    final folded = <String, SearchGroup>{};
    for (final item in bks) {
      final name = item.name.trim().toLowerCase();
      final author = item.author.trim().toLowerCase();
      final key = author.isEmpty ? name : '$name|$author';
      final group = folded.putIfAbsent(key, () => SearchGroup(item));
      if (item.sourceUrl.isNotEmpty) {
        group.sourceUrls.add(item.sourceUrl);
      } else if (item.sourceName.isNotEmpty) {
        group.sourceUrls.add(item.sourceName);
      }
      if (item.sourceName.isNotEmpty) {
        group.sourceNames.add(item.sourceName);
      }
    }
    return folded.values.toList(growable: false);
  }

  void clear() {
    searchHistory = [];
    showResult = false;
    bks = [];
    _deduper.clear();
    historyKey = "";
    page = 1;
    word = "";
    noMore = false;
    loading = false;
    searchedSources = 0;
    totalSources = 0;
    failedSources = 0;
    failedSourceNames.clear();
    reports.clear();
    retryingSources.clear();
    _searchGen++;
  }

  Future<bool> getSearchData(int gen) async {
    //收起键盘
    if (context != null) {
      FocusScope.of(context!).requestFocus(FocusNode());
    }

    // Meta only — hydrate rules per pool chunk to avoid MethodChannel OOM.
    final meta = await _sources.getEnabled();
    if (gen != _searchGen) return false;

    final groups = SourceGroups.collect(meta);
    groupOptions = groups;
    final searchable = SourceGroups.filter(meta, groupFilter)
        .where((s) => s.searchUrl.isNotEmpty && s.enabled)
        .toList();
    if (searchable.isEmpty) {
      if (gen != _searchGen) return false;
      noMore = true;
      BotToast.showText(text: '请先在「书源管理」导入并启用书源');
      notifyListeners();
      return true;
    }

    totalSources = searchable.length;
    searchedSources = 0;
    failedSources = 0;
    failedSourceNames.clear();
    notifyListeners();
    _softTimer?.cancel();
    softTimeoutElapsed = false;
    _softTimer = Timer(firstScreenWindow, () {
      if (_disposed || gen != _searchGen || !loading) return;
      softTimeoutElapsed = true;
      notifyListeners();
    });

    try {
      var newHits = 0;
      final poolSize = sourceConcurrency.clamp(1, 20);
      for (var i = 0; i < searchable.length; i += poolSize) {
        if (gen != _searchGen) return false;
        final chunkMeta = searchable.skip(i).take(poolSize).toList();
        final chunk = await _sources.getByUrls(
          chunkMeta.map((e) => e.bookSourceUrl).toList(),
        );
        if (gen != _searchGen) return false;
        // Notify per source, not per chunk: the first reply should show up
        // immediately even when other sources are still timing out.
        final futures = chunk.map((s) async {
          SourceSearchReport report;
          try {
            report = await _engine.searchWithReport(s, word, page);
          } catch (e) {
            report = SourceSearchReport(
              sourceUrl: s.bookSourceUrl,
              sourceName: s.bookSourceName,
              keyword: word,
              page: page,
              issue: SourceSearchIssue.unknown,
              detail: '搜索异常（${e.runtimeType}）。',
            );
          }
          if (gen != _searchGen) return;
          _recordReport(report);
          if (report.hits.isNotEmpty) {
            final items = report.hits
                .map(_toSearchItem)
                .toList(growable: false);
            newHits += _deduper.addAll(items, bks);
            unawaited(_enrich(items));
          }
          searchedSources = (searchedSources + 1).clamp(0, totalSources);
          notifyListeners();
        });
        await Future.wait(futures);
        if (gen != _searchGen) return false;
      }
      if (gen != _searchGen) return false;
      _softTimer?.cancel();
      softTimeoutElapsed = false;
      // Relevance order + keyword cache are finalised only when the sweep
      // settles, so the list does not shuffle while sources are streaming in.
      _rankResults();
      if (bks.isNotEmpty) _keywordCache.put(word, bks);
      fromCache = false;
      // All sources failing is not "end of results": a retry may still work.
      if (newHits == 0 && !allSourcesFailed) {
        noMore = true;
      }
      return true;
    } catch (e) {
      if (gen != _searchGen) return false;
      BotToast.showText(text: '搜索失败：${Redact.userMessage(e)}');
      return false;
    }
  }

  SearchItem _toSearchItem(SearchBook h) {
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
    final src = await _sources.getByUrl(item.sourceUrl);
    if (src == null) return '';
    return _engine.fetchCover(src, item.bookUrl);
  }

  /// Rank hits by name/author relevance, keeping arrival order inside a rank.
  void _rankResults() {
    if (bks.length < 2 || word.isEmpty) return;
    final ranked = SearchResultRanker.rank(bks, word);
    bks
      ..clear()
      ..addAll(ranked);
  }

  void _recordReport(SourceSearchReport report) {
    reports.removeWhere((r) => r.sourceUrl == report.sourceUrl);
    reports.add(report);
    final failed = reports.where((r) => r.failed).toList(growable: false);
    failedSources = failed.length;
    failedSourceNames
      ..clear()
      ..addAll(
        failed.map((r) => r.sourceName.isEmpty ? r.sourceUrl : r.sourceName),
      );
  }

  /// Re-run one failed source with the current keyword/page.
  ///
  /// Does not bump the sweep generation: other sources keep their results.
  Future<SourceSearchReport?> retrySource(String sourceUrl) async {
    if (word.isEmpty || retryingSources.contains(sourceUrl)) return null;
    final src = await _sources.getByUrl(sourceUrl);
    if (src == null) {
      BotToast.showText(text: '书源不存在或已删除');
      return null;
    }
    final gen = _searchGen;
    retryingSources.add(sourceUrl);
    notifyListeners();
    try {
      final report = await _engine.searchWithReport(src, word, page);
      if (gen != _searchGen) return null;
      _recordReport(report);
      if (report.hits.isNotEmpty) {
        final items = report.hits.map(_toSearchItem).toList(growable: false);
        final added = _deduper.addAll(items, bks);
        if (added > 0) noMore = false;
        unawaited(_enrich(items));
        _rankResults();
        if (bks.isNotEmpty) _keywordCache.put(word, bks);
      }
      notifyListeners();
      return report;
    } finally {
      retryingSources.remove(sourceUrl);
      notifyListeners();
    }
  }

  /// Load the group list for the filter chips (no sweep).
  Future<void> loadGroupOptions() async {
    try {
      final meta = await _sources.getEnabled();
      if (_disposed) return;
      groupOptions = SourceGroups.collect(meta);
      notifyListeners();
    } catch (_) {
      // Chips simply stay hidden when the source list is unavailable.
    }
  }

  /// Switch the group scope; an existing result refreshes under the new scope.
  void setGroupFilter(String group) {
    final next = group.trim();
    if (next == groupFilter) return;
    groupFilter = next;
    notifyListeners();
    if (showResult && word.isNotEmpty && !loading) {
      unawaited(search(word));
    }
  }

  /// Stop waiting for the remaining sources after the first-screen window.
  ///
  /// In-flight requests are not cancelled; their results are dropped by the
  /// generation guard. Hits already on screen stay.
  void stopWaiting() {
    if (!loading) return;
    _softTimer?.cancel();
    softTimeoutElapsed = false;
    _rankResults();
    if (bks.isNotEmpty) _keywordCache.put(word, bks);
    fromCache = false;
    _searchGen++;
    loading = false;
    notifyListeners();
  }

  /// Retry every failed source in completion order.
  Future<void> retryFailedSources() async {
    final urls = failures
        .map((r) => r.sourceUrl)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    for (final url in urls) {
      await retrySource(url);
    }
  }

  /// Run one source with an arbitrary keyword, without touching sweep state.
  Future<SourceSearchReport?> testSingleSource(
    String sourceUrl,
    String keyword,
  ) async {
    final key = keyword.trim();
    if (key.isEmpty) return null;
    final src = await _sources.getByUrl(sourceUrl);
    if (src == null) {
      BotToast.showText(text: '书源不存在或已删除');
      return null;
    }
    return _engine.searchWithReport(src, key, 1);
  }

  /// Open book detail via local source rules.
  Future<BookInfo?> openDetail(SearchItem item) async {
    final resolved = AnalyzeUrl.sanitizeUrl(item.bookUrl, base: item.sourceUrl);
    if (item.sourceUrl.isEmpty || resolved.isEmpty) {
      BotToast.showText(text: '该书详情地址无效，可能书源规则不完整');
      return null;
    }
    final src = await _sources.getByUrl(item.sourceUrl);
    if (src == null) {
      BotToast.showText(text: '书源不存在或已删除：${item.sourceName}');
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
      final info = await _engine.bookInfo(src, resolved, seed: seed);
      return info;
    } catch (e) {
      BotToast.showText(text: '获取详情失败，请稍后重试');
      return null;
    }
  }

  Future<void> loadMore() async {
    if (loading || noMore || word.isEmpty) return;
    final nextPage = page + 1;
    page = nextPage;
    final gen = ++_searchGen;
    loading = true;
    notifyListeners();
    try {
      final ok = await getSearchData(gen);
      // A failed page must not skip a page number on the next attempt.
      if (gen == _searchGen && !ok) page = nextPage - 1;
    } finally {
      if (gen == _searchGen) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setHistory(String value) {
    if (value.isEmpty) {
      return;
    }
    for (var ii = 0; ii < searchHistory.length; ii++) {
      if (searchHistory[ii] == value) {
        searchHistory.removeAt(ii);
      }
    }
    searchHistory.insert(0, value);
    if (SpUtil.haveKey(historyKey)) {
      SpUtil.remove(historyKey);
    }
    SpUtil.putStringList(historyKey, searchHistory);
  }

  void initHistory() {
    if (SpUtil.haveKey(historyKey)) {
      searchHistory = SpUtil.getStringList(historyKey);
    }
    notifyListeners();
  }

  void clearHistory() {
    SpUtil.remove(historyKey);
    searchHistory = [];
    notifyListeners();
  }

  void reset() {
    if (word.isEmpty) {
      return;
    }
    word = "";
    page = 1;
    showResult = false;
    noMore = false;
    loading = false;
    searchedSources = 0;
    totalSources = 0;
    failedSources = 0;
    failedSourceNames.clear();
    reports.clear();
    retryingSources.clear();
    fromCache = false;
    _deduper.clear();
    _searchGen++;
    notifyListeners();
  }

  Future search(String w) async {
    final next = w.trim();
    if (next.isEmpty) return;
    if (loading && next == word) return;
    word = next;
    setHistory(next);
    showResult = true;
    bks = [];
    _deduper.clear();
    page = 1;
    noMore = false;
    searchedSources = 0;
    totalSources = 0;
    failedSources = 0;
    failedSourceNames.clear();
    reports.clear();
    retryingSources.clear();
    _softTimer?.cancel();
    softTimeoutElapsed = false;
    // Show the previous hits for this keyword immediately; the sweep below
    // still runs and refreshes them in the background.
    fromCache = false;
    final cached = _keywordCache.get(next);
    if (cached != null && cached.isNotEmpty) {
      _deduper.addAll(cached, bks);
      fromCache = true;
    }
    final gen = ++_searchGen;
    loading = true;
    notifyListeners(); // UI shows the spinner / cached results
    try {
      await getSearchData(gen);
    } finally {
      if (gen == _searchGen) {
        loading = false;
        notifyListeners();
      }
    }
  }
}
