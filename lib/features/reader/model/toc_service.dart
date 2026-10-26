import 'package:flutter/foundation.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
import 'package:langhuan/features/sources/util/title_format.dart';
import 'package:bot_toast/bot_toast.dart';

/// Remote TOC fetch + local catalog persistence for the active book.
class TocService {
  TocService({
    required this.engine,
    required this.chapters,
    required this.ensureBookRow,
    required this.resolveSource,
  });

  final BookSourceEngine engine;
  final ChapterRepository chapters;
  final Future<void> Function(Book book) ensureBookRow;
  final Future<BookSource?> Function(Book book) resolveSource;

  /// Fetch TOC from the active book source.
  Future<List<ChapterTocEntry>?> fetchRemote(Book book) async {
    final source = await resolveSource(book);
    if (source == null) {
      BotToast.showText(text: '书源不存在：${book.originName}');
      return null;
    }
    final tocUrl = book.tocUrl.isNotEmpty
        ? book.tocUrl
        : (book.bookUrl.isNotEmpty ? book.bookUrl : '');
    if (tocUrl.isEmpty) return null;
    try {
      AppLog.i(
        'Read',
        'fetchRemoteToc source=${source.bookSourceName} '
            'tocUrl=$tocUrl chapterList=${source.ruleToc.chapterList}',
      );
      final list = await engine.toc(source, tocUrl);
      AppLog.i('Read', 'fetchRemoteToc got ${list.length} chapters');
      return mapChapters(book, list);
    } catch (e, st) {
      AppLog.e(
        'Read',
        'fetchRemoteToc failed for $tocUrl',
        error: e,
        stackTrace: st,
      );
      BotToast.showText(text: '目录加载失败：$e');
      return null;
    }
  }

  /// Map engine chapters to TOC entries, attaching each volume header to the
  /// chapters that follow it.
  ///
  /// Volume rows themselves never become entries: reading progress, chapter
  /// ids and the `(book_id, ord)` index all stay on readable chapters only.
  @visibleForTesting
  static List<ChapterTocEntry> mapChapters(
    Book book,
    List<SourceChapter> list,
  ) {
    var currentVolume = '';
    var volumeOrd = -1;
    final entries = <ChapterTocEntry>[];
    for (final c in list) {
      if (c.isVolume) {
        final name = normalizeTitle(c.name);
        if (name.isEmpty) continue;
        currentVolume = name;
        volumeOrd++;
        continue;
      }
      if (c.url.isEmpty) continue;
      entries.add(
        ChapterTocEntry(
          id: makeChapterId(book.id, c.url),
          title: normalizeTitle(c.name),
          url: c.url,
          hasBody: false,
          ord: entries.length,
          volumeTitle: currentVolume,
          volumeOrd: currentVolume.isEmpty ? -1 : volumeOrd,
        ),
      );
    }
    return entries;
  }

  /// Merge remote TOC into local state + DB.
  ///
  /// Returns the updated in-memory chapter list, or null if nothing changed /
  /// fetch failed / stale book.
  Future<List<ChapterTocEntry>?> load({
    required Book book,
    required List<ChapterTocEntry> current,
    required bool init,
    required bool Function() isStillActive,
  }) async {
    final bookId = book.id;
    final list = await fetchRemote(book);
    if (list == null || list.isEmpty) return null;
    if (!isStillActive()) {
      AppLog.i('Read', 'loadToc drop stale toc for $bookId');
      return null;
    }

    await ensureBookRow(book);
    if (!isStillActive()) return null;

    if (init || current.isEmpty) {
      await chapters.syncToc(list, bookId, sourceUrl: book.sourceUrl);
      if (!isStillActive()) return null;
      // Rehydrate hasBody (and ord) from DB — syncToc preserves bodies for
      // matching ids, but the remote list always has hasBody:false.
      final hydrated = await chapters.getToc(bookId);
      if (!isStillActive()) return null;
      AppLog.i(
        'Read',
        'toc saved init=${list.length} hydrated=${hydrated.length} id=$bookId',
      );
      return hydrated.isNotEmpty ? hydrated : list;
    }

    final existing = current.map((e) => e.url).toSet();
    final fresh = list.where((e) => !existing.contains(e.url)).toList();
    if (fresh.isEmpty) return current;
    for (final c in fresh) {
      c.ord = current.length;
      current.add(c);
    }
    await chapters.appendToc(fresh, bookId, sourceUrl: book.sourceUrl);
    if (!isStillActive()) return null;
    AppLog.i('Read', 'toc append ${fresh.length} id=$bookId');
    return current;
  }
}
