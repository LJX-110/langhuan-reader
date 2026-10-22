import 'dart:async';

import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_node.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:bot_toast/bot_toast.dart';

/// Menu-driven content refresh: TOC reload, body refresh, font relayout.
class ReaderContentReloader {
  ReaderContentReloader({
    required this.chaptersRepo,
    required this.bookOf,
    required this.chaptersOf,
    required this.setChaptersLoading,
    required this.setLoadingHint,
    required this.loadToc,
    required this.fetchChapterBody,
    required this.loadChapter,
    required this.setCurPage,
    required this.removeWarm,
    required this.clearPictures,
    required this.openChapterAt,
    required this.restorePageIndex,
    required this.toggleMenu,
    required this.showLoading,
    required this.hideLoading,
    required this.markNeedsPaint,
    required this.notify,
    this.cancelPagination,
  });

  final ChapterRepository chaptersRepo;
  final Book? Function() bookOf;
  final List<ChapterTocEntry> Function() chaptersOf;
  final void Function(bool value) setChaptersLoading;
  final void Function(String text) setLoadingHint;
  final Future Function({bool init}) loadToc;
  final Future<String> Function(String id, {int? idx}) fetchChapterBody;
  final Future<ReadPage?> Function(int idx) loadChapter;
  final void Function(ReadPage? page) setCurPage;
  final void Function(String chapterId) removeWarm;
  final void Function() clearPictures;
  final Future Function(int idx, bool jump, {bool showLoading}) openChapterAt;
  final void Function(int savedIndex) restorePageIndex;
  final void Function() toggleMenu;
  final Future<void> Function(String text) showLoading;
  final void Function() hideLoading;
  final void Function() markNeedsPaint;
  final void Function() notify;

  /// Cancel in-flight Rust/Dart progressive pagination (ABI v3).
  final void Function()? cancelPagination;

  bool _refreshing = false;
  Timer? _relayoutTimer;

  /// Coalesce slider drags / repeated +/- taps into one relayout. The value
  /// label still updates immediately; only the expensive pagination waits.
  void scheduleRelayout() {
    _relayoutTimer?.cancel();
    _relayoutTimer = Timer(const Duration(milliseconds: 260), () {
      _relayoutTimer = null;
      unawaited(relayoutPages());
    });
  }

  void cancelScheduledRelayout() {
    _relayoutTimer?.cancel();
    _relayoutTimer = null;
  }

  Future<void> reloadChapters() async {
    final b = bookOf();
    if (b == null) return;
    setChaptersLoading(true);
    setLoadingHint('正在重新加载目录…');
    notify();
    try {
      // init:true re-syncs full remote TOC while preserving bodies for same ids.
      await loadToc(init: true);
      if (chaptersOf().isEmpty) {
        BotToast.showText(text: '目录为空，请检查书源或网络');
      }
    } finally {
      setChaptersLoading(false);
      notify();
    }
  }

  Future<void> reloadCurrentPage() async {
    if (_refreshing) return;
    final b = bookOf();
    if (b == null) return;
    final chapters = chaptersOf();
    if (chapters.isEmpty ||
        b.chapterIndex < 0 ||
        b.chapterIndex >= chapters.length) {
      return;
    }
    _refreshing = true;
    toggleMenu();
    final chapter = chapters[b.chapterIndex];
    await showLoading('正在刷新正文…');
    try {
      var content = await fetchChapterBody(chapter.id, idx: b.chapterIndex)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => '章节内容加载超时，请检查网络或换源',
          );
      if (content.isEmpty) {
        content = '章节内容加载失败，请检查书源或换源后重试';
      }
      final looksOk =
          !content.startsWith('章节内容加载失败') &&
          !content.startsWith('章节内容加载超时') &&
          !content.startsWith('书源不存在') &&
          !content.startsWith('章节地址为空');
      if (looksOk) {
        await chaptersRepo.updateBodies([ChapterNode(content, chapter.id)]);
        chapter.hasBody = true;
      } else {
        BotToast.showText(text: '刷新失败，请检查书源或网络');
      }
      // Drop warm snapshot so loadChapter hits DB (updateBodies only clears SQLite).
      removeWarm(chapter.id);
      setCurPage(await loadChapter(b.chapterIndex));
      markNeedsPaint();
      notify();
    } catch (e) {
      AppLog.w('Read', 'reload current page failed', error: e);
      BotToast.showText(text: '刷新失败，请稍后重试');
    } finally {
      _refreshing = false;
      hideLoading();
    }
  }

  Future<void> relayoutPages() async {
    final b = bookOf();
    if (b == null) return;
    cancelPagination?.call();
    clearPictures();
    // Font/metrics changed — drop disk page layouts for the active book only.
    try {
      await chaptersRepo.clearAllPageLayouts(bookId: b.id);
      AppLog.i('Read', 'cleared page cache on layout change book=${b.id}');
    } catch (e) {
      AppLog.w('Read', 'clearAllPageLayouts failed', error: e);
    }
    final keepIndex = b.pageIndex;
    await openChapterAt(b.chapterIndex, false, showLoading: false);
    restorePageIndex(keepIndex);
    markNeedsPaint();
    notify();
  }
}
