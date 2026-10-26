import 'dart:async';

import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/features/reader/model/reader_loading_presenter.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Opens a chapter into the pre/cur/next window and paints neighbors.
class ChapterWindowController {
  ChapterWindowController({
    required this.bookOf,
    required this.chaptersLength,
    required this.loadChapter,
    required this.warmDiskCaches,
    required this.messagePage,
    required this.showLoading,
    required this.hideLoading,
    required this.curPageOf,
    required this.chapterTitleOf,
    required this.onLoadFailed,
    required this.onLoadSucceeded,
    required this.setCurPage,
    required this.setPrePage,
    required this.setNextPage,
    required this.clearPictures,
    required this.warmPictures,
    required this.restorePageIndex,
    required this.markNeedsPaint,
    required this.notify,
  });

  final Book? Function() bookOf;
  final int Function() chaptersLength;
  final Future<ReadPage?> Function(int idx) loadChapter;
  final Future<void> Function(int centerIdx) warmDiskCaches;
  final Future<ReadPage> Function(String title, String message) messagePage;
  final Future<void> Function(String text) showLoading;
  final void Function() hideLoading;
  final ReadPage? Function() curPageOf;
  final String Function(int idx) chapterTitleOf;
  final void Function(
    int idx,
    String title,
    Object error, {
    required bool keptContent,
  })
  onLoadFailed;
  final void Function() onLoadSucceeded;
  final void Function(ReadPage? page) setCurPage;
  final void Function(ReadPage? page) setPrePage;
  final void Function(ReadPage? page) setNextPage;
  final void Function() clearPictures;

  /// Record current page picture + schedule prev/next after chapter open.
  final void Function() warmPictures;
  final void Function(int savedIndex) restorePageIndex;
  final void Function() markNeedsPaint;
  final void Function() notify;

  /// Bumped on every [openAt] so stale neighbor futures cannot overwrite pages.
  int _openGeneration = 0;

  /// Last readable page before a TOC preview, restored when loading fails.
  ReadPage? _fallbackPage;

  int? _failedIndex;

  /// Paint the target chapter title immediately, without touching progress.
  ///
  /// Keeps the last readable page so a failed load can restore it instead of
  /// leaving a placeholder or an error page on screen.
  void previewChapter(int idx) {
    final b = bookOf();
    final len = chaptersLength();
    if (b == null || len <= 0) return;
    final target = idx.clamp(0, len - 1).toInt();
    final current = curPageOf();
    if (current != null && !current.isPlaceholder && current.pages.isNotEmpty) {
      _fallbackPage = current;
    }
    setCurPage(
      ReaderLoadingPresenter.syncPlaceholder(
        '正在加载…',
        chapterTitle: chapterTitleOf(target),
      ),
    );
    clearPictures();
    markNeedsPaint();
    notify();
    AppLog.i('Read', 'toc-preview idx=$target title=${chapterTitleOf(target)}');
  }

  Future<void> openAt(int idx, bool jump, {bool showLoadingUi = true}) async {
    final keepIndex = bookOf()?.pageIndex ?? 0;
    final prevChapterIndex = bookOf()?.chapterIndex ?? 0;
    final prevPageIndex = bookOf()?.pageIndex ?? 0;
    final gen = ++_openGeneration;
    final openBookId = bookOf()?.id;
    if (showLoadingUi) {
      await showLoading('正在加载…');
    }

    final len = chaptersLength();
    final safePrevChapter = len > 0
        ? prevChapterIndex.clamp(0, len - 1).toInt()
        : 0;
    final safePrevPage = prevPageIndex < 0 ? 0 : prevPageIndex;

    try {
      final b = bookOf();
      if (b != null && len > 0) {
        if (idx < 0) idx = 0;
        if (idx >= len) idx = len - 1;
        b.chapterIndex = idx;
      }

      // Disk warm is only a cache; never delay the chapter body behind it.
      unawaited(warmDiskCaches(idx));

      var cur = await loadChapter(idx);
      if (gen != _openGeneration || bookOf()?.id != openBookId) return;

      if (cur == null || _isLoadFailure(cur)) {
        final error = cur == null
            ? StateError('empty chapter page')
            : StateError('chapter body unavailable');
        if (_restoreFallback(
          gen,
          openBookId,
          idx,
          safePrevChapter,
          safePrevPage,
          error,
        )) {
          return;
        }
        cur ??= await messagePage('加载失败', '当前章节内容为空，请检查书源或点击菜单刷新。');
        if (gen != _openGeneration || bookOf()?.id != openBookId) return;
        _markLoadFailed(idx, error, keptContent: false);
      }

      setCurPage(cur);
      clearPictures();
      _fallbackPage = null;
      _failedIndex = null;
      onLoadSucceeded();

      final center = idx;
      final centerBookId = openBookId;
      for (var step = 1; step <= ReadSetting.prefetchForward; step++) {
        _preloadNeighbor(center + step, center, gen, centerBookId, next: true);
      }
      for (var step = 1; step <= ReadSetting.prefetchBack; step++) {
        _preloadNeighbor(center - step, center, gen, centerBookId, next: false);
      }

      if (jump) {
        bookOf()?.pageIndex = 0;
      } else {
        restorePageIndex(keepIndex);
      }
      // Eager current picture + post-frame neighbors (cover first gesture).
      warmPictures();
      markNeedsPaint();
      notify();
    } catch (e, st) {
      if (gen != _openGeneration) return;
      AppLog.e(
        'Read',
        'openChapterAt failed idx=$idx',
        error: e,
        stackTrace: st,
      );
      if (_restoreFallback(
        gen,
        openBookId,
        idx,
        safePrevChapter,
        safePrevPage,
        e,
      )) {
        return;
      }
      final cur = await messagePage('加载失败', '章节加载异常：$e');
      if (gen != _openGeneration || bookOf()?.id != openBookId) return;
      _markLoadFailed(idx, e, keptContent: false);
      setCurPage(cur);
      notify();
    } finally {
      if (showLoadingUi && gen == _openGeneration) {
        hideLoading();
      }
    }
  }

  /// Retry the last failed chapter, reusing the preview title path.
  Future<void> retryFailed() async {
    final idx = _failedIndex;
    if (idx == null) return;
    previewChapter(idx);
    await openAt(idx, true, showLoadingUi: false);
  }

  bool _restoreFallback(
    int gen,
    String? openBookId,
    int idx,
    int prevChapter,
    int prevPage,
    Object error,
  ) {
    if (gen != _openGeneration || bookOf()?.id != openBookId) return false;
    final fallback = _fallbackPage;
    if (fallback == null || fallback.pages.isEmpty) return false;
    setCurPage(fallback);
    final b = bookOf();
    if (b != null) {
      b.chapterIndex = prevChapter;
      b.pageIndex = prevPage;
    }
    _fallbackPage = null;
    _markLoadFailed(idx, error, keptContent: true);
    notify();
    return true;
  }

  void _markLoadFailed(
    int idx,
    Object error, {
    required bool keptContent,
  }) {
    _failedIndex = idx;
    onLoadFailed(
      idx,
      chapterTitleOf(idx),
      error,
      keptContent: keptContent,
    );
  }

  void _preloadNeighbor(
    int target,
    int center,
    int gen,
    String? centerBookId, {
    required bool next,
  }) {
    unawaited(
      loadChapter(target)
          .then((page) {
            if (gen != _openGeneration) return;
            if (bookOf()?.id != centerBookId) return;
            if (bookOf()?.chapterIndex != center) return;
            if (next) {
              setNextPage(page);
            } else {
              setPrePage(page);
            }
            // Cross-chapter cover bottom layer becomes available — warm now.
            warmPictures();
          })
          .catchError((Object e, StackTrace st) {
            AppLog.w(
              'Read',
              'preload chapter $target failed',
              error: e,
            );
          }),
    );
  }

  static bool _isLoadFailure(ReadPage page) {
    final text = page.chapterContent;
    return text.startsWith('章节内容加载失败') ||
        text.startsWith('章节内容加载超时') ||
        text.startsWith('书源不存在') ||
        text.startsWith('章节地址为空') ||
        text.startsWith('内容为空');
  }
}
