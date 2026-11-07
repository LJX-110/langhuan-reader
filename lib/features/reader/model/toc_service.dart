import 'package:flutter/foundation.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/entities/replace_rule.dart';
import 'package:langhuan/features/sources/engine/source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/util/book_id.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';
import 'package:langhuan/features/sources/util/title_format.dart';
import 'package:langhuan/design/components/feedback.dart';

/// Remote TOC fetch + local catalog persistence for the active book.
class TocService {
  TocService({
    required this.engine,
    required this.chapters,
    required this.ensureBookRow,
    required this.resolveSource,
    required this.loadReplaceRules,
  });

  final SourceEngine engine;
  final ChapterRepository chapters;
  final Future<void> Function(Book book) ensureBookRow;
  final Future<BookSource?> Function(Book book) resolveSource;
  final Future<List<ReplaceRule>> Function() loadReplaceRules;

  /// Fetch TOC from the active book source.
  Future<List<ChapterTocEntry>?> fetchRemote(Book book) async {
    final source = await resolveSource(book);
    if (source == null) {
      showError('书源不存在：${book.originName}');
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
            'tocUrl=${Redact.forLog(tocUrl)} '
            'chapterList=${source.ruleToc.chapterList}',
      );
      final list = await engine.toc(
        source,
        tocUrl,
        bookUrl: book.bookUrl,
        bookName: book.name,
      );
      AppLog.i('Read', 'fetchRemoteToc got ${list.length} chapters');
      return mapChapters(book, list, rules: await _activeRules());
    } catch (e, st) {
      AppLog.e(
        'Read',
        'fetchRemoteToc failed for ${Redact.forLog(tocUrl)}',
        error: e,
        stackTrace: st,
      );
      showError('目录加载失败：${Redact.userMessage(e)}');
      return null;
    }
  }

  /// Title rules must never block a TOC refresh; a failed read just means
  /// "no purification" for this fetch.
  Future<List<ReplaceRule>> _activeRules() async {
    try {
      return await loadReplaceRules();
    } catch (e) {
      AppLog.w('Read', 'replace rules load failed', error: e);
      return const [];
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
    List<SourceChapter> list, {
    List<ReplaceRule> rules = const [],
  }) {
    var currentVolume = '';
    var volumeOrd = -1;
    final entries = <ChapterTocEntry>[];
    for (final c in list) {
      if (c.isVolume) {
        final name = normalizeTitle(
          applyReplaceRules(c.name, rules, scope: ReplaceRuleScope.title),
        );
        if (name.isEmpty) continue;
        currentVolume = name;
        volumeOrd++;
        continue;
      }
      if (c.url.isEmpty) continue;
      entries.add(
        ChapterTocEntry(
          id: makeChapterId(book.id, c.url),
          // 空章节名兜底「第 N 章」：个别源规则抓歪 / 字段缺失时，
          // 目录、阅读页与书签都不会出现空白标题。
          title: displayReadingTitle(
            applyReplaceRules(c.name, rules, scope: ReplaceRuleScope.title),
            index: entries.length,
          ),
          url: c.url,
          hasBody: false,
          ord: entries.length,
          volumeTitle: currentVolume,
          volumeOrd: currentVolume.isEmpty ? -1 : volumeOrd,
          info: c.info,
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
