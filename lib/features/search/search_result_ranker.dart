import 'package:langhuan/data/entities/search_item.dart';

/// Relevance ordering for merged search results.
///
/// Book matching beats author matching; within the same rank the original
/// arrival order is preserved (stable), so the list does not shuffle between
/// sweeps.
class SearchResultRanker {
  const SearchResultRanker._();

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 0 exact name · 1 name prefix · 2 name contains · 3 author · 4 rest.
  static int rankOf(SearchItem item, String keyword) {
    final key = _norm(keyword);
    if (key.isEmpty) return 4;
    final name = _norm(item.name);
    if (name == key) return 0;
    if (name.startsWith(key)) return 1;
    if (name.contains(key)) return 2;
    if (_norm(item.author).contains(key)) return 3;
    return 4;
  }

  static List<SearchItem> rank(List<SearchItem> items, String keyword) {
    if (items.length < 2 || keyword.trim().isEmpty) return items;
    final indexed = <(int, SearchItem)>[
      for (var i = 0; i < items.length; i++) (i, items[i]),
    ];
    indexed.sort((a, b) {
      final byRank = rankOf(a.$2, keyword).compareTo(rankOf(b.$2, keyword));
      if (byRank != 0) return byRank;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}
