import 'dart:collection';

import 'package:langhuan/data/entities/search_item.dart';

/// Short-lived keyword result cache.
///
/// A repeated search shows the previous hits immediately and then refreshes in
/// the background; entries expire after [ttl] and the map is capped so a long
/// session cannot grow without bound.
class SearchKeywordCache {
  SearchKeywordCache({
    this.ttl = const Duration(minutes: 10),
    this.maxEntries = 20,
  });

  final Duration ttl;
  final int maxEntries;

  final LinkedHashMap<String, ({DateTime at, List<SearchItem> items})> _map =
      LinkedHashMap<String, ({DateTime at, List<SearchItem> items})>();

  static String _key(String keyword) =>
      keyword.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  List<SearchItem>? get(String keyword) {
    final key = _key(keyword);
    if (key.isEmpty) return null;
    final hit = _map[key];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _map.remove(key);
      return null;
    }
    // Touch for LRU ordering.
    _map.remove(key);
    _map[key] = hit;
    return List<SearchItem>.of(hit.items);
  }

  void put(String keyword, List<SearchItem> items) {
    final key = _key(keyword);
    if (key.isEmpty || items.isEmpty) return;
    _map.remove(key);
    _map[key] = (at: DateTime.now(), items: List<SearchItem>.of(items));
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();

  int get length => _map.length;
}
