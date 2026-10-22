import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
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

  /// True after a page returns empty results — stops further load-more.
  bool noMore = false;

  /// How many searchable sources were scanned in the current page sweep.
  int searchedSources = 0;

  /// Total searchable sources for the current page sweep.
  int totalSources = 0;

  /// Sources that timed out or failed in the current sweep.
  int failedSources = 0;

  String historyKey = "";
  int page = 1;
  var word = "";
  TextEditingController? controller;

  final BookSourceEngine _engine = BookSourceEngine();
  final SourceRepository _sources = SourceRepository.instance;

  /// Concurrent source search pool size.
  static const int poolSize = 10;

  /// Bumps on each new search/loadMore so stale chunks are discarded.
  int _searchGen = 0;

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
    historyKey = "";
    page = 1;
    word = "";
    noMore = false;
    loading = false;
    searchedSources = 0;
    totalSources = 0;
    failedSources = 0;
    _searchGen++;
  }

  Future<void> getSearchData(int gen) async {
    //收起键盘
    if (context != null) {
      FocusScope.of(context!).requestFocus(FocusNode());
    }

    // Meta only — hydrate rules per pool chunk to avoid MethodChannel OOM.
    final meta = await _sources.getEnabled();
    if (gen != _searchGen) return;

    final searchable = meta
        .where((s) => s.searchUrl.isNotEmpty && s.enabled)
        .toList();
    if (searchable.isEmpty) {
      if (gen != _searchGen) return;
      noMore = true;
      BotToast.showText(text: '请先在「书源管理」导入并启用书源');
      notifyListeners();
      return;
    }

    totalSources = searchable.length;
    searchedSources = 0;
    failedSources = 0;
    notifyListeners();

    try {
      var pageHits = 0;
      for (var i = 0; i < searchable.length; i += poolSize) {
        if (gen != _searchGen) return;
        final chunkMeta = searchable.skip(i).take(poolSize).toList();
        final chunk = await _sources.getByUrls(
          chunkMeta.map((e) => e.bookSourceUrl).toList(),
        );
        if (gen != _searchGen) return;
        // Notify per source, not per chunk: the first reply should show up
        // immediately even when other sources are still timing out.
        final futures = chunk.map((s) async {
          List<SearchBook> hits = const [];
          try {
            hits = await _engine
                .search(s, word, page)
                .timeout(BookSourceEngine.sourceTimeout);
          } catch (_) {
            if (gen != _searchGen) return;
            failedSources++;
            searchedSources = (searchedSources + 1).clamp(0, totalSources);
            notifyListeners();
            return;
          }
          if (gen != _searchGen) return;
          pageHits += hits.length;
          for (final h in hits) {
            bks.add(_toSearchItem(h));
          }
          searchedSources = (searchedSources + 1).clamp(0, totalSources);
          notifyListeners();
        });
        await Future.wait(futures);
        if (gen != _searchGen) return;
      }
      if (gen != _searchGen) return;
      if (pageHits == 0) {
        noMore = true;
      }
    } catch (e) {
      if (gen != _searchGen) return;
      BotToast.showText(text: '搜索失败：$e');
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
    page += 1;
    final gen = ++_searchGen;
    loading = true;
    notifyListeners();
    try {
      await getSearchData(gen);
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
    _searchGen++;
    notifyListeners();
  }

  Future search(String w) async {
    word = w;
    if (w.isEmpty) return;
    setHistory(w);
    showResult = true;
    bks = [];
    page = 1;
    noMore = false;
    searchedSources = 0;
    totalSources = 0;
    failedSources = 0;
    final gen = ++_searchGen;
    loading = true;
    notifyListeners(); // UI shows loading spinner
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
