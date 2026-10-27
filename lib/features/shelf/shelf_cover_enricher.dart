import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';

/// Fills shelf covers the source left empty.
///
/// Search / explore lists already enrich through `CoverEnricher`; books that
/// were added earlier (or whose detail page had no cover rule) kept an empty
/// `cover_url`, which is why some shelf rows showed only the typographic
/// placeholder. Each book is attempted once per app session, with the detail
/// page's `og:image` as the engine-side fallback.
class ShelfCoverEnricher {
  ShelfCoverEnricher({
    BookRepository? books,
    SourceRepository? sources,
    BookSourceEngine? engine,
  }) : _books = books ?? BookRepository.instance,
       _sources = sources ?? SourceRepository.instance,
       _engine = engine ?? BookSourceEngine();

  final BookRepository _books;
  final SourceRepository _sources;
  final BookSourceEngine _engine;

  /// Keeps one cold start from firing dozens of detail-page requests.
  static const int maxPerPass = 8;
  static const int concurrency = 2;

  static final Set<String> _attempted = <String>{};

  @visibleForTesting
  static void resetAttempted() => _attempted.clear();

  /// Try to fetch covers for up to [maxPerPass] cover-less books.
  ///
  /// [onUpdated] fires after each batch that wrote at least one cover so the
  /// shelf can refresh; failures are remembered for the session.
  Future<void> enrich(
    List<Book> books, {
    required Future<void> Function() onUpdated,
  }) async {
    final pending = <Book>[];
    for (final book in books) {
      if (pending.length >= maxPerPass) break;
      if (book.coverUrl.isNotEmpty || book.bookUrl.isEmpty) continue;
      if (!_attempted.add(book.id)) continue;
      pending.add(book);
    }
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += concurrency) {
      final end = math.min(i + concurrency, pending.length);
      final chunk = pending.sublist(i, end);
      var changed = false;
      await Future.wait(
        chunk.map((book) async {
          try {
            final source = await _sources.getByUrl(book.sourceUrl);
            if (source == null) return;
            final cover = await _engine.fetchCover(source, book.bookUrl);
            if (cover.isEmpty) return;
            await _books.updateCover(book.id, cover);
            changed = true;
          } catch (e) {
            AppLog.w('Cover', 'shelf enrich failed id=${book.id}', error: e);
          }
        }),
      );
      if (changed) await onUpdated();
    }
  }
}
