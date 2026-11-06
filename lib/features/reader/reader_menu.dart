import 'package:bot_toast/bot_toast.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/data/entities/bookmark.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/repositories/bookmark_repository.dart';
import 'package:langhuan/design/motion.dart';
import 'package:langhuan/design/theme/color_model.dart';
import 'package:langhuan/features/reader/menu/reader_bottom_bar.dart';
import 'package:langhuan/features/reader/menu/reader_chapter_panel.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/menu/reader_download_panel.dart';
import 'package:langhuan/features/reader/menu/reader_find_bar.dart';
import 'package:langhuan/features/reader/menu/reader_progress_bar.dart';
import 'package:langhuan/features/reader/menu/reader_settings_panel.dart';
import 'package:langhuan/features/reader/menu/reader_top_bar.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Reader chrome overlay: top bar plus a bottom panel whose content switches
/// between chapters, settings, layout and download.
class ReaderMenu extends ConsumerStatefulWidget {
  const ReaderMenu({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  ConsumerState<ReaderMenu> createState() => _MenuState();
}

enum Type { SLIDE, MORE_SETTING, DOWNLOAD, LAYOUT }

class _MenuState extends ConsumerState<ReaderMenu> {
  Type type = Type.SLIDE;
  late ReadModel _readModel;
  late ColorModel _colorModel;

  bool _finding = false;
  final TextEditingController _findCtrl = TextEditingController();
  List<({int page, String snippet})> _findMatches = const [];
  int _findIndex = 0;

  final BookmarkRepository _bookmarks = BookmarkRepository.instance;
  String? _bookmarkKey;
  bool _bookmarked = false;

  /// 进度条拖动状态：手指按住时用 [_dragValue] 显示，不跟随页面进度。
  bool _progressDragging = false;
  double _dragValue = 0;

  /// 指针被父级取消后可能不走 onDragCancel 直接进 onEnd，提交跳转前检查。
  bool _progressPointerCancelled = false;

  @override
  void initState() {
    super.initState();
    _readModel = ref.read(readModelProvider);
    _colorModel = ref.read(colorModelProvider);
  }

  @override
  void dispose() {
    _findCtrl.dispose();
    super.dispose();
  }

  /// Match reader paper so chrome doesn't clash with the page underneath.
  ReaderChrome get _chrome => ReaderChrome(_readModel.paperTheme);

  void _refresh() {
    if (mounted) setState(() {});
  }

  String? get _currentBookmarkId {
    final b = _readModel.book;
    if (b == null) return null;
    return Bookmark.idFor(b.id, b.chapterIndex, b.pageIndex);
  }

  /// Re-check the bookmark flag only when the book/chapter/page changes.
  void _syncBookmark() {
    final id = _currentBookmarkId;
    if (id == null || id == _bookmarkKey) return;
    _bookmarkKey = id;
    _bookmarks.exists(id).then((value) {
      if (mounted && id == _bookmarkKey) {
        setState(() => _bookmarked = value);
      }
    }, onError: (_) {});
  }

  Future<void> _toggleBookmark() async {
    final b = _readModel.book;
    final page = _readModel.curPage;
    if (b == null || page == null) return;
    final id = Bookmark.idFor(b.id, b.chapterIndex, b.pageIndex);
    // 先翻转（乐观更新），失败回滚——图标零等待（批次 7·R6）。
    final wasBookmarked = _bookmarked;
    final willBookmark = !wasBookmarked;
    setState(() => _bookmarked = willBookmark);
    try {
      if (willBookmark) {
        await _bookmarks.add(
          Bookmark(
            id: id,
            bookId: b.id,
            chapterIndex: b.chapterIndex,
            pageIndex: b.pageIndex,
            chapterName: b.readingChapter,
            excerpt: _pageExcerpt(page),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else {
        await _bookmarks.remove(id);
      }
      if (!mounted) return;
      BotToast.showText(text: willBookmark ? '已添加书签' : '已取消书签');
    } catch (e) {
      if (mounted) setState(() => _bookmarked = wasBookmarked);
      BotToast.showText(text: '书签操作失败：${Redact.userMessage(e)}');
    }
  }

  String _pageExcerpt(ReadPage page) {
    final index = _readModel.book?.pageIndex ?? 0;
    if (index < 0 || index >= page.pages.length) return '';
    final text = page.pages[index].lines.map((line) => line.text).join().trim();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}…';
  }

  void _openFind() {
    setState(() {
      _finding = true;
      _findCtrl.clear();
      _findMatches = const [];
      _findIndex = 0;
    });
  }

  void _closeFind() {
    FocusScope.of(context).unfocus();
    setState(() {
      _finding = false;
      _findCtrl.clear();
      _findMatches = const [];
      _findIndex = 0;
    });
  }

  void _onFindChanged(String value) {
    final query = value.trim();
    final List<({int page, String snippet})> matches = query.isEmpty
        ? const []
        : _collectMatches(query);
    setState(() {
      _findMatches = matches;
      _findIndex = 0;
    });
    if (matches.isNotEmpty) _jumpToMatch(0);
  }

  /// Search each rendered line so results map to pages without relying on the
  /// pager's byte offsets.
  List<({int page, String snippet})> _collectMatches(String query) {
    final pages = _readModel.curPage?.pages ?? const [];
    final needle = query.toLowerCase();
    final matches = <({int page, String snippet})>[];
    for (var p = 0; p < pages.length; p++) {
      for (final line in pages[p].lines) {
        final text = line.text;
        final lower = text.toLowerCase();
        var from = 0;
        while (true) {
          final at = lower.indexOf(needle, from);
          if (at < 0) break;
          final start = (at - 8).clamp(0, text.length);
          final end = (at + query.length + 8).clamp(0, text.length);
          matches.add((page: p, snippet: text.substring(start, end).trim()));
          from = at + needle.length;
        }
      }
    }
    return matches;
  }

  void _jumpToMatch(int index) {
    if (_findMatches.isEmpty) return;
    _readModel.jumpToPage(_findMatches[index].page);
  }

  void _stepFind(int delta) {
    if (_findMatches.isEmpty) return;
    final next = (_findIndex + delta) % _findMatches.length;
    final wrapped = next < 0 ? next + _findMatches.length : next;
    setState(() => _findIndex = wrapped);
    _jumpToMatch(wrapped);
  }

  Widget _bottomHead(ReaderChrome chrome) {
    final panel = switch (type) {
      Type.MORE_SETTING => ReaderSettingsPanel(
        readModel: _readModel,
        colorModel: _colorModel,
        chrome: chrome,
        onChanged: _refresh,
        onOpenLayout: () => setState(() => type = Type.LAYOUT),
      ),
      Type.LAYOUT => ReaderLayoutPanel(
        readModel: _readModel,
        chrome: chrome,
        onChanged: _refresh,
        onBack: () => setState(() => type = Type.MORE_SETTING),
      ),
      Type.DOWNLOAD => ReaderDownloadPanel(
        readModel: _readModel,
        chrome: chrome,
      ),
      _ => ReaderChapterPanel(
        readModel: _readModel,
        chrome: chrome,
        onChanged: _refresh,
      ),
    };
    // 面板互切承接：高度弹性过渡 + 内容淡入微上移（不再瞬间替换、高度跳变）。
    return AnimatedSize(
      duration: AppMotion.enter,
      curve: AppMotion.ease,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.contact,
        switchInCurve: AppMotion.ease,
        switchOutCurve: AppMotion.retract,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, .02),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            // 面板互切期间，淡出中的旧面板不再接收点击——防止"幽灵按钮"
            // 被二次点到（重复触发；与 read_book 菜单层同一约定）。
            // 同 read_book 菜单层：ignoring 用 AnimatedBuilder 实时求值，
            // 避免 transitionBuilder 早期快照 dismissed 造成面板按钮指针锁死。
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, inner) => IgnorePointer(
                ignoring:
                    animation.status == AnimationStatus.reverse ||
                    animation.status == AnimationStatus.dismissed,
                child: inner,
              ),
              child: SlideTransition(position: slide, child: child),
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(type), child: panel),
      ),
    );
  }

  void _dismissMenu() {
    _finding = false;
    _findCtrl.clear();
    _findMatches = const [];
    _findIndex = 0;
    FocusScope.of(context).unfocus();
    type = Type.SLIDE;
    if (_readModel.showMenu) {
      _readModel.toggleShowMenu();
    }
  }

  /// 专注模式：阅读页只留章首头与正文（隐藏行头与时间 / 页码）。
  /// 开启后立即收起菜单，让用户直接看到干净的页面；关闭时保持菜单可见。
  void _toggleFocus() {
    final enabled = !ReadSetting.getFocusMode();
    ReadSetting.setFocusMode(enabled);
    _readModel.scheduleRelayout();
    if (enabled) {
      _dismissMenu();
    } else {
      _refresh();
    }
  }

  /// 全书进度（0~1）：章节等权 + 章内页码比例。
  double get _bookProgress {
    final total = _readModel.chapters.length;
    if (total == 0) return 0;
    final b = _readModel.book;
    final pages = _readModel.curPage?.pages.length ?? 0;
    final chapter = (b?.chapterIndex ?? 0).clamp(0, total - 1).toInt();
    final page = (b?.pageIndex ?? 0)
        .clamp(0, pages > 0 ? pages - 1 : 0)
        .toInt();
    return ReaderProgress.valueOf(
      chapter: chapter,
      pageIndex: page,
      pages: pages,
      total: total,
    );
  }

  /// 多章（或单章多页）才显示进度条。
  bool get _showProgressBar {
    final total = _readModel.chapters.length;
    if (total == 0) return false;
    if (total > 1) return true;
    return (_readModel.curPage?.pages.length ?? 0) > 1;
  }

  /// 上次悬停的章（拖动过章界响一次轻触，批次 7·R8）。
  int? _lastDragChapter;

  void _onProgressDragStart() {
    _lastDragChapter = _readModel.book?.chapterIndex ?? 0;
    setState(() {
      _progressDragging = true;
      _progressPointerCancelled = false;
      _dragValue = _bookProgress;
    });
  }

  void _onProgressDragUpdate(double value) {
    final total = _readModel.chapters.length;
    if (total > 1) {
      final target = ReaderProgress.targetOf(value, total);
      if (target.chapter != _lastDragChapter) {
        _lastDragChapter = target.chapter;
        HapticFeedback.selectionClick();
      }
    }
    setState(() => _dragValue = value);
  }

  void _onProgressDragCancel() {
    setState(() {
      _progressDragging = false;
      _progressPointerCancelled = false;
    });
  }

  Future<void> _onProgressDragEnd() async {
    final cancelled = _progressPointerCancelled;
    final target = _dragValue;
    setState(() {
      _progressDragging = false;
      _progressPointerCancelled = false;
    });
    if (cancelled) return;
    await _jumpToProgress(target);
  }

  /// 松手定位：换算目标章节 + 章内页；跨章先开章，再补页内跳转。
  Future<void> _jumpToProgress(double value) async {
    final total = _readModel.chapters.length;
    if (total == 0) return;
    final target = ReaderProgress.targetOf(value, total);
    final current = _readModel.book?.chapterIndex ?? 0;
    if (target.chapter != current) {
      _readModel.previewChapter(target.chapter);
      await _readModel.openChapterAt(target.chapter, true, showLoading: false);
      if (!mounted || _readModel.chapterLoadError != null) return;
    }
    final pages = _readModel.curPage?.pages.length ?? 0;
    if (pages > 1) {
      _readModel.jumpToPage((target.ratio * (pages - 1)).round());
    }
    _readModel.scheduleProgressSave(delay: Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when theme or reader chrome-relevant fields change.
    _colorModel = ref.watch(colorModelProvider);
    ref.watch(
      readModelProvider.select(
        (m) => (
          m.book?.chapterIndex,
          m.book?.pageIndex,
          m.book?.name,
          m.tapLeftToAdvance,
          m.paperTheme,
          m.currentAnimationMode,
          m.chapters.length,
        ),
      ),
    );
    _readModel = ref.read(readModelProvider);
    _syncBookmark();

    final chrome = _chrome;
    final isNight = _colorModel.dark;

    // Full-screen stack: dimmed/tap-to-dismiss layer under chrome, so the
    // blank reading area always closes the menu (including when settings is open).
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Catch taps on the reading area.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissMenu,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // Top chrome
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _finding
                ? ReaderFindBar(
                    chrome: chrome,
                    controller: _findCtrl,
                    index: _findIndex,
                    total: _findMatches.length,
                    snippet: _findMatches.isEmpty
                        ? ''
                        : _findMatches[_findIndex].snippet,
                    onChanged: _onFindChanged,
                    onPrev: () => _stepFind(-1),
                    onNext: () => _stepFind(1),
                    onClose: _closeFind,
                  )
                : ReaderTopBar(
                    readModel: _readModel,
                    chrome: chrome,
                    onSearch: _openFind,
                    bookmarked: _bookmarked,
                    onBookmark: _toggleBookmark,
                    onExit: widget.onExit,
                  ),
          ),
          // Bottom panel (settings / chapter / download)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: chrome.panelBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A000000),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: chrome.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _bottomHead(chrome),
                      Divider(height: 1, color: chrome.divider),
                      if (_showProgressBar)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: ReaderProgressBar(
                            chrome: chrome,
                            value: _progressDragging
                                ? _dragValue
                                : _bookProgress,
                            dragging: _progressDragging,
                            previewText: ReaderProgress.previewOf(
                              _progressDragging ? _dragValue : _bookProgress,
                              _readModel.chapters.length,
                            ),
                            onDragStart: _onProgressDragStart,
                            onDragUpdate: _onProgressDragUpdate,
                            onDragEnd: _onProgressDragEnd,
                            onDragCancel: _onProgressDragCancel,
                            onPointerCancel: () =>
                                _progressPointerCancelled = true,
                          ),
                        ),
                      ReaderBottomBar(
                        chrome: chrome,
                        night: isNight,
                        focusActive: ReadSetting.getFocusMode(),
                        downloadActive: type == Type.DOWNLOAD,
                        settingsActive: type == Type.MORE_SETTING,
                        onChapters: () {
                          eventBus.fire(OpenChapters('dd'));
                          _readModel.toggleShowMenu();
                        },
                        onToggleNight: () async {
                          ref.read(colorModelProvider).switchModel();
                          final night = ref.read(colorModelProvider).dark;
                          await _readModel.setPaperTheme(
                            night ? PaperTheme.night : PaperTheme.cream,
                          );
                          _refresh();
                        },
                        onFocus: _toggleFocus,
                        onDownload: () {
                          setState(() {
                            type = type == Type.DOWNLOAD
                                ? Type.SLIDE
                                : Type.DOWNLOAD;
                          });
                        },
                        onSettings: () {
                          setState(() {
                            type = type == Type.MORE_SETTING
                                ? Type.SLIDE
                                : Type.MORE_SETTING;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
