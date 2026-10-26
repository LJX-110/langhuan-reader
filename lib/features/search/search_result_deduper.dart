import 'package:langhuan/data/entities/search_item.dart';

/// Keeps search results unique across pages.
///
/// A source whose `searchUrl` has no `{{page}}` placeholder returns the same
/// page forever. Counting those repeats as new hits made `loadMore()` loop
/// without end, so the accumulator reports how many ids were genuinely new.
class SearchResultDeduper {
  final Set<String> _ids = <String>{};

  int addAll(Iterable<SearchItem> items, List<SearchItem> target) {
    var added = 0;
    for (final item in items) {
      if (!_ids.add(item.id)) continue;
      target.add(item);
      added++;
    }
    return added;
  }

  void clear() => _ids.clear();
}
