import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';

/// One cached-chapter hit for cross-chapter find.
class CachedChapterSearchHit {
  const CachedChapterSearchHit({
    required this.chapterIndex,
    required this.title,
    required this.snippet,
    required this.occurrences,
  });

  final int chapterIndex;
  final String title;
  final String snippet;
  final int occurrences;
}

/// Searches **cached** chapter bodies only (never online, never network).
///
/// Reuses the same text cleaner as the reader, so snippets read like the
/// rendered body instead of raw HTML.
class CachedChapterSearch {
  CachedChapterSearch._();

  static Future<List<CachedChapterSearchHit>> search({
    required String bookId,
    required String query,
    ChapterRepository? repo,
  }) async {
    final needle = query.trim();
    if (bookId.isEmpty || needle.isEmpty) return const [];
    final chapters = repo ?? ChapterRepository.instance;
    try {
      final rows = await chapters.searchCachedBodies(bookId, needle);
      final lowerNeedle = needle.toLowerCase();
      final hits = <CachedChapterSearchHit>[];
      for (final row in rows) {
        final text = htmlToPlainText(row.body).replaceAll(RegExp(r'\s+'), ' ');
        final lower = text.toLowerCase();
        var from = 0;
        var count = 0;
        var snippet = '';
        while (from < lower.length) {
          final at = lower.indexOf(lowerNeedle, from);
          if (at < 0) break;
          count++;
          if (count == 1) {
            final start = (at - 10).clamp(0, text.length);
            final end = (at + needle.length + 10).clamp(0, text.length);
            snippet = text.substring(start, end).trim();
          }
          from = at + lowerNeedle.length;
        }
        if (count == 0) continue;
        hits.add(
          CachedChapterSearchHit(
            chapterIndex: row.ord,
            title: row.title,
            snippet: snippet,
            occurrences: count,
          ),
        );
      }
      return hits;
    } catch (e) {
      AppLog.w('Read', 'cached chapter search failed', error: e);
      return const [];
    }
  }
}
