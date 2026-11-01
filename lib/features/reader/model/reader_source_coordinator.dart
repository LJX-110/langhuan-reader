import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/reader/model/chapter_download_service.dart';
import 'package:langhuan/features/reader/model/download_center.dart';
import 'package:langhuan/features/reader/model/source_switch_service.dart';
import 'package:langhuan/features/sources/source_model.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:bot_toast/bot_toast.dart';

/// Active book source resolution + download / switch orchestration.
class ReaderSourceCoordinator {
  ReaderSourceCoordinator({
    required this.downloads,
    required this.sourceSwitch,
    required this.bookOf,
    required this.chaptersOf,
    required this.setChapters,
    required this.clearDiskWarm,
    required this.resetPages,
    required this.clearPictures,
    required this.openChapterAt,
    required this.showLoading,
    required this.hideLoading,
    required this.loadToc,
    required this.notify,
  });

  final ChapterDownloadService downloads;
  final SourceSwitchService sourceSwitch;
  final Book? Function() bookOf;
  final List<ChapterTocEntry> Function() chaptersOf;
  final void Function(List<ChapterTocEntry> chapters) setChapters;
  final void Function() clearDiskWarm;
  final void Function() resetPages;
  final void Function() clearPictures;
  final Future Function(int idx, bool jump, {bool showLoading}) openChapterAt;
  final Future<void> Function(String text) showLoading;
  final void Function() hideLoading;
  final Future Function({bool init}) loadToc;
  final void Function() notify;

  BookSource? activeSource;

  Future<void> ensureSource() async {
    final b = bookOf();
    if (b == null || Book.isLocalSource(b.sourceUrl)) return;
    if (activeSource != null && activeSource!.bookSourceUrl == b.sourceUrl) {
      return;
    }
    activeSource = await SourceModel().findByUrl(b.sourceUrl);
  }

  Future<String> fetchChapterBody(String id, {int? idx}) async {
    final b = bookOf();
    if (b == null || Book.isLocalSource(b.sourceUrl)) return '';
    await ensureSource();
    return downloads.fetchBody(
      source: activeSource,
      toc: chaptersOf(),
      chapterId: id,
      idx: idx,
    );
  }

  Future<void> downloadAll(int start) async {
    final book = bookOf();
    if (book == null || Book.isLocalSource(book.sourceUrl)) return;
    if (chaptersOf().isEmpty) {
      await loadToc(init: true);
    }
    await ensureSource();
    // 队列化下载：状态 / 暂停 / 继续 / 失败重试由 DownloadCenter 统一管理。
    DownloadCenter.instance.start(
      book: book,
      toc: chaptersOf(),
      source: activeSource,
      start: start,
    );
  }

  /// 清除本书离线缓存（章节正文 + 分页缓存）；书架 / 进度 / 书签保留。
  /// 对齐文库「清除这本缓存」的语义。
  Future<void> clearDownloadCache() async {
    final b = bookOf();
    if (b == null) return;
    DownloadCenter.instance.forget(b.id);
    await downloads.chapters.clearBodies(b.id);
    for (final chapter in chaptersOf()) {
      chapter.hasBody = false;
    }
    clearDiskWarm();
    clearPictures();
    notify();
  }

  /// Switch active source for the current book, remap progress, reload toc.
  ///
  /// When there is no active reading session (e.g. book detail page), only
  /// rewrites book metadata / TOC in DB — does not open a chapter window.
  Future<bool> switchSource(BookSource source, SearchBook hit) async {
    final b = bookOf();
    if (b == null) return false;
    if (Book.isLocalSource(b.sourceUrl)) {
      BotToast.showText(text: '本地书不支持换源');
      return false;
    }
    final chapters = chaptersOf();
    final oldName = (b.chapterIndex >= 0 && b.chapterIndex < chapters.length)
        ? chapters[b.chapterIndex].title
        : b.readingChapter;
    final oldIndex = b.chapterIndex;
    // Detail page sets book without hydrating a session — skip chapter open.
    final hasSession = chapters.isNotEmpty;

    await showLoading('正在换源…');
    try {
      final result = await sourceSwitch.switchTo(
        book: b,
        source: source,
        hit: hit,
        oldChapterName: oldName,
        oldChapterIndex: oldIndex,
      );
      if (result == null) return false;

      activeSource = result.source;
      setChapters(result.chapters);
      // 换源后旧的下载任务描述的章节 id / url 已失效，直接丢弃。
      DownloadCenter.instance.forget(b.id);
      clearDiskWarm();
      resetPages();
      clearPictures();
      if (hasSession) {
        await openChapterAt(b.chapterIndex, true);
        final mapped = result.mappedChapterIndex;
        final updated = chaptersOf();
        final name = (mapped >= 0 && mapped < updated.length)
            ? updated[mapped].title
            : '';
        BotToast.showText(text: '已切换至「${source.bookSourceName}」，定位到：$name');
      } else {
        BotToast.showText(text: '已切换至「${source.bookSourceName}」');
      }
      notify();
      return true;
    } finally {
      hideLoading();
    }
  }
}
