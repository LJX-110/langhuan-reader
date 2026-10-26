import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:langhuan/data/entities/search_item.dart';

/// Fill missing list covers from the book detail page.
///
/// Only the first visible rows are enriched; requests are capped in count and
/// concurrency, and failures are remembered so a broken cover is not retried
/// on every rebuild. The cache is shared app-wide, keyed by book URL, so the
/// same book is never fetched twice across 发现 / 搜索.
class CoverEnricher {
  CoverEnricher({required this.fetch});

  /// Runs the detail-page cover lookup for one item. Must not throw.
  final Future<String> Function(SearchItem item) fetch;

  static const int maxConcurrent = 3;
  static const int _cacheLimit = 400;

  static final LinkedHashMap<String, String> _cache =
      LinkedHashMap<String, String>();

  static String? cacheGet(String bookUrl) {
    final hit = _cache.remove(bookUrl);
    if (hit == null) return null;
    _cache[bookUrl] = hit; // touch for LRU
    return hit;
  }

  static void cachePut(String bookUrl, String cover) {
    _cache.remove(bookUrl);
    _cache[bookUrl] = cover;
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  @visibleForTesting
  static int get cacheSize => _cache.length;

  /// Enrich up to [limit] rows that still lack a cover.
  ///
  /// [onUpdated] fires after each row gains a cover; rows known to have none
  /// are cached as empty and skipped on later calls.
  Future<void> enrich(
    List<SearchItem> items, {
    int limit = 8,
    required void Function() onUpdated,
  }) async {
    final pending = <SearchItem>[];
    for (final item in items) {
      if (pending.length >= limit) break;
      if (item.bookUrl.isEmpty || item.coverUrl.isNotEmpty) continue;
      final cached = cacheGet(item.bookUrl);
      if (cached != null) {
        if (cached.isNotEmpty) {
          item.coverUrl = cached;
          onUpdated();
        }
        continue; // known empty → do not request again
      }
      pending.add(item);
    }
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += maxConcurrent) {
      final end = math.min(i + maxConcurrent, pending.length);
      final chunk = pending.sublist(i, end);
      await Future.wait(
        chunk.map((item) async {
          var cover = '';
          try {
            cover = await fetch(item);
          } catch (_) {
            cover = '';
          }
          cachePut(item.bookUrl, cover);
          if (cover.isEmpty) return;
          if (item.coverUrl.isEmpty) {
            item.coverUrl = cover;
            onUpdated();
          }
        }),
      );
    }
  }
}
