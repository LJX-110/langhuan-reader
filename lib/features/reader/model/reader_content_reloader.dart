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
    this.onRelayout,
  });

  final ChapterRepository chaptersRepo;
  final Book? Function() bookOf;
  final List<ChapterTocEntry> Function() chaptersOf;
  final void Function(bool value) setChaptersLoading;
  final void Function(String text) setLoadingHint;
  final Future<bool> Function({bool init}) loadToc;
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

  /// Called after a font / spacing relayout replaced every page layout.
  /// Scroll mode uses it to drop its stale window (page heights changed).
  final void Function()? onRelayout;

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

  Future<bool> reloadChapters() async {
    final b = bookOf();
    if (b == null) return false;
    final oldIndex = b.chapterIndex;
    final before = chaptersOf();
    final old = oldIndex >= 0 && oldIndex < before.length
        ? before[oldIndex]
        : null;
    final savedPage = b.pageIndex;

    setChaptersLoading(true);
    setLoadingHint('正在重新加载目录…');
    notify();
    try {
      // init:true re-syncs full remote TOC while preserving bodies for same ids.
      final loaded = await loadToc(init: true);
      if (!loaded) return false;

      final list = chaptersOf();
      if (list.isEmpty) {
        BotToast.showText(text: '目录为空，请检查书源或网络');
        return false;
      }

      // Keep the reader on the same chapter (by stable id, then url); its
      // index may have moved after the remote TOC changed.
      var target = old == null ? -1 : list.indexWhere((c) => c.id == old.id);
      if (target < 0 && old != null && old.url.isNotEmpty) {
        target = list.indexWhere((c) => c.url == old.url);
      }
      if (target < 0) {
        target = oldIndex.clamp(0, list.length - 1).toInt();
      }

      b.chapterIndex = target;
      b.readingChapter = list[target].title;
      // The TOC may point at new urls; cached pictures describe the old body.
      clearPictures();
      await openChapterAt(target, false, showLoading: false);
      restorePageIndex(savedPage);
      markNeedsPaint();
      notify();
      return true;
    } catch (e) {
      AppLog.w('Read', 'reload chapters failed', error: e);
      BotToast.showText(text: '目录刷新失败，请稍后重试');
      return false;
    } finally {
      setChaptersLoading(false);
      notify();
    }
  }

  Future<bool> reloadCurrentPage() async {
    if (_refreshing) return false;
    final b = bookOf();
    if (b == null) return false;
    final chapters = chaptersOf();
    if (chapters.isEmpty ||
        b.chapterIndex < 0 ||
        b.chapterIndex >= chapters.length) {
      return false;
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
      if (!looksOk) {
        BotToast.showText(text: '刷新失败，请检查书源或网络');
        return false;
      }
      await chaptersRepo.updateBodies([ChapterNode(content, chapter.id)]);
      chapter.hasBody = true;
      // Drop warm snapshot so loadChapter hits DB (updateBodies only clears SQLite).
      removeWarm(chapter.id);
      final page = await loadChapter(b.chapterIndex);
      // The cached paint for this key describes the pre-refresh body.
      clearPictures();
      setCurPage(page);
      markNeedsPaint();
      notify();
      return page != null;
    } catch (e) {
      AppLog.w('Read', 'reload current page failed', error: e);
      BotToast.showText(text: '刷新失败，请稍后重试');
      return false;
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
    onRelayout?.call();
  }
}
