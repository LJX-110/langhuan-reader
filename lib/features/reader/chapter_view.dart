import 'dart:async';
import 'dart:math' as math;

import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/reader/model/toc_rows.dart';
import 'package:langhuan/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

/// Bounded chapter catalog panel (Wenku8-style sheet) with search + jump.
///
/// Presented as a modal bottom sheet over the reader: current chapter is the
/// scroll target, search accepts a chapter name or an exact chapter number.
class ChapterView extends ConsumerStatefulWidget {
  const ChapterView({super.key});

  @override
  ConsumerState<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends ConsumerState<ChapterView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool showToTopBtn = false;
  bool _centeredOnce = false;
  bool _searching = false;
  String _query = '';

  bool get _dark => SpUtil.getBool(PrefsKeys.dark, defValue: false);
  Color get _scaffold => _dark ? AppColors.scaffoldDark : AppColors.scaffold;
  Color get _surface => _dark ? AppColors.surfaceDark : AppColors.surface;
  Color get _primary => _dark ? AppColors.textOnDark : AppColors.textPrimary;
  Color get _secondary => AppColors.textSecondary;
  Color get _tertiary => AppColors.textTertiary;
  Color get _divider => _dark ? AppColors.dividerDark : AppColors.divider;

  @override
  void initState() {
    super.initState();
    // The sheet overlays the immersive reader; system bars stay hidden.
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCurrentChapter();
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final minIndex = positions
        .map((e) => e.index)
        .reduce((a, b) => a < b ? a : b);
    final next = minIndex >= 8;
    if (next != showToTopBtn && mounted) {
      setState(() => showToTopBtn = next);
    }
  }

  void _jumpTo(int chapterIndex, {double alignment = 0}) {
    if (!_itemScrollController.isAttached) return;
    final chapters = ref.read(readModelProvider).chapters;
    if (chapters.isEmpty) return;
    final row = tocRowForChapter(
      _rows(),
      chapterIndex.clamp(0, chapters.length - 1),
    );
    _itemScrollController.jumpTo(index: row, alignment: alignment);
  }

  Future<void> _scrollTo(int chapterIndex, {double alignment = 0}) async {
    if (!_itemScrollController.isAttached) return;
    final chapters = ref.read(readModelProvider).chapters;
    if (chapters.isEmpty) return;
    final row = tocRowForChapter(
      _rows(),
      chapterIndex.clamp(0, chapters.length - 1),
    );
    await _itemScrollController.scrollTo(
      index: row,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: alignment,
    );
  }

  void _centerCurrentChapter() {
    final model = ref.read(readModelProvider);
    final chapters = model.chapters;
    if (chapters.isEmpty || !_itemScrollController.isAttached) return;
    final cur = (model.book?.chapterIndex ?? 0).clamp(0, chapters.length - 1);
    _jumpTo(cur, alignment: 0.35);
    _centeredOnce = true;
  }

  List<TocRow> _rows() => buildTocRows(
    ref.read(readModelProvider).chapters,
    query: _query,
  );

  Future<void> _openChapter(int index) async {
    final data = ref.read(readModelProvider);
    final book = data.book;
    if (book == null) return;
    if (index < 0 || index >= data.chapters.length) return;
    // Paint the target title immediately; progress indices stay untouched
    // until the body actually loads.
    data.previewChapter(index);
    Navigator.of(context).pop();
    unawaited(() async {
      await data.openChapterAt(index, true, showLoading: false);
      if (data.chapterLoadError == null) {
        data.scheduleProgressSave(delay: Duration.zero);
      }
    }());
  }

  Future<void> _showJumpDialog() async {
    final model = ref.read(readModelProvider);
    final total = model.chapters.length;
    if (total == 0) return;
    final cur = ((model.book?.chapterIndex ?? 0) + 1).clamp(1, total);
    final ctrl = TextEditingController(text: '$cur');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text('跳转到章节', style: TextStyle(color: _primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '共 $total 章，输入章节序号（1–$total）',
                style: TextStyle(fontSize: 13, color: _secondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: _primary),
                decoration: InputDecoration(
                  hintText: '章节序号',
                  hintStyle: TextStyle(color: _tertiary),
                  filled: true,
                  fillColor: _dark
                      ? const Color(0xFF2A2A2A)
                      : AppColors.scaffold,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null) Navigator.pop(ctx, n);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: _secondary)),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx, n);
              },
              child: Text(
                '确定',
                style: TextStyle(color: AppColors.accentOf(context)),
              ),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;
    final index = (result - 1).clamp(0, total - 1);

    if (_query.isNotEmpty) {
      // Clear search so the full list is shown, then jump.
      setState(() {
        _query = '';
        _searchCtrl.clear();
        _searching = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    final current = ref.read(readModelProvider).book?.chapterIndex ?? 0;
    if ((index - current).abs() > 20) {
      _jumpTo(index, alignment: 0.35);
    } else {
      await _scrollTo(index, alignment: 0.35);
    }
  }

  Future<void> _goCurrent() async {
    final model = ref.read(readModelProvider);
    final chapters = model.chapters;
    if (chapters.isEmpty) return;
    final cur = (model.book?.chapterIndex ?? 0).clamp(0, chapters.length - 1);
    if (_query.isNotEmpty) {
      setState(() {
        _query = '';
        _searchCtrl.clear();
        _searching = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await _scrollTo(cur, alignment: 0.35);
  }

  Future<void> topOrBottom() async {
    final chapters = ref.read(readModelProvider).chapters;
    if (chapters.isEmpty || _query.isNotEmpty) return;
    if (showToTopBtn) {
      await _scrollTo(0);
    } else {
      await _scrollTo(chapters.length - 1);
    }
  }

  Future<void> refresh() async {
    final model = ref.read(readModelProvider);
    await model.reloadChapters();
    if (!mounted) return;
    final chapters = model.chapters;
    if (chapters.isEmpty) return;
    final cur = (model.book?.chapterIndex ?? 0).clamp(0, chapters.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollTo(cur, alignment: 0.35);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(readModelProvider.select((m) => m.chapters));
    final cur = ref.watch(
      readModelProvider.select((m) => m.book?.chapterIndex ?? 0),
    );
    final bookName = ref.watch(
      readModelProvider.select((m) => m.book?.name ?? '目录'),
    );
    final chaptersLoading = ref.watch(
      readModelProvider.select((m) => m.chaptersLoading),
    );
    final loadingHint = ref.watch(
      readModelProvider.select((m) => m.loadingHint),
    );
    final rows = buildTocRows(chapters, query: _query);

    if (!_centeredOnce && chapters.isNotEmpty && _query.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _centeredOnce) return;
        _centerCurrentChapter();
      });
    }

    // 有界面板（对齐文库）：屏高约 64% 封顶；键盘弹出时整体上浮，
    // 安全区与输入法高度都从可用高度里扣，避免搜索时被键盘遮住。
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final available = math.max(
      200.0,
      media.size.height - media.viewPadding.vertical - bottomInset - 40,
    );
    final panelHeight = math.min(media.size.height * .64, available);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: panelHeight,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Material(
            color: _scaffold,
            child: Column(
              children: [
                _Header(
                  title: bookName,
                  subtitle: chapters.isEmpty
                      ? '暂无章节'
                      : '共 ${chapters.length} 章 · 当前第 ${cur + 1} 章',
                  dark: _dark,
                  primary: _primary,
                  secondary: _secondary,
                  surface: _surface,
                  searching: _searching,
                  searchCtrl: _searchCtrl,
                  searchFocus: _searchFocus,
                  onClose: () => Navigator.of(context).maybePop(),
                  onToggleSearch: () {
                    setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _query = '';
                        _searchCtrl.clear();
                        _searchFocus.unfocus();
                      } else {
                        _searchFocus.requestFocus();
                      }
                    });
                  },
                  onQueryChanged: (v) {
                    setState(() {
                      _query = v;
                      _centeredOnce = true; // don't re-center while filtering
                    });
                  },
                  onClearQuery: () {
                    setState(() {
                      _query = '';
                      _searchCtrl.clear();
                    });
                  },
                  onJump: chapters.isEmpty ? null : _showJumpDialog,
                  onLocate: chapters.isEmpty ? null : _goCurrent,
                ),
                Expanded(
                  child: chaptersLoading && chapters.isEmpty
                      ? Center(
                          child: Text(
                            loadingHint.isEmpty ? '正在加载目录…' : loadingHint,
                            style: TextStyle(color: _secondary, fontSize: 14),
                          ),
                        )
                      : chapters.isEmpty
                      ? Center(
                          child: Text(
                            '暂无章节',
                            style: TextStyle(color: _secondary, fontSize: 14),
                          ),
                        )
                      : rows.isEmpty
                      ? Center(
                          child: Text(
                            '未找到匹配章节',
                            style: TextStyle(color: _secondary, fontSize: 14),
                          ),
                        )
                      : ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            if (row.isVolume) {
                              return _VolumeTile(
                                title: row.title,
                                count: row.count,
                                tertiary: _tertiary,
                              );
                            }
                            final index = row.chapterIndex;
                            final chapter = row.chapter!;
                            final selected = index == cur;
                            final cached = chapter.hasBody;
                            return _ChapterTile(
                              index: index,
                              title: chapter.title,
                              info: chapter.info,
                              selected: selected,
                              cached: cached,
                              dark: _dark,
                              primary: _primary,
                              tertiary: _tertiary,
                              onTap: () => _openChapter(index),
                            );
                          },
                        ),
                ),
                _BottomBar(
                  dark: _dark,
                  surface: _surface,
                  primary: _primary,
                  secondary: _secondary,
                  divider: _divider,
                  showToTop: showToTopBtn && _query.isEmpty,
                  reloading: chaptersLoading,
                  onReload: chaptersLoading ? null : refresh,
                  onJumpList: chaptersLoading || _query.isNotEmpty
                      ? null
                      : topOrBottom,
                  onJumpChapter: chaptersLoading || chapters.isEmpty
                      ? null
                      : _showJumpDialog,
                  onLocateCurrent: chaptersLoading || chapters.isEmpty
                      ? null
                      : _goCurrent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool dark;
  final Color primary;
  final Color secondary;
  final Color surface;
  final bool searching;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final VoidCallback onClose;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback? onJump;
  final VoidCallback? onLocate;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.dark,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.searching,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onClose,
    required this.onToggleSearch,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onJump,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      elevation: 0,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  tooltip: '关闭目录',
                  icon: Icon(Icons.close, size: 22, color: primary),
                  onPressed: onClose,
                ),
                Expanded(
                  child: searching
                      ? _SearchField(
                          controller: searchCtrl,
                          focusNode: searchFocus,
                          dark: dark,
                          primary: primary,
                          secondary: secondary,
                          onChanged: onQueryChanged,
                          onClear: onClearQuery,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  tooltip: searching ? '关闭搜索' : '搜索章节',
                  icon: Icon(
                    searching ? Icons.close : Icons.search,
                    size: 22,
                    color: primary,
                  ),
                  onPressed: onToggleSearch,
                ),
                if (!searching) ...[
                  IconButton(
                    tooltip: '跳转章节',
                    icon: Icon(Icons.low_priority, size: 22, color: primary),
                    onPressed: onJump,
                  ),
                  IconButton(
                    tooltip: '定位当前',
                    icon: Icon(
                      Icons.my_location_outlined,
                      size: 20,
                      color: primary,
                    ),
                    onPressed: onLocate,
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppColors.divider.withValues(alpha: dark ? 0.2 : 1),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool dark;
  final Color primary;
  final Color secondary;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.dark,
    required this.primary,
    required this.secondary,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A2A) : AppColors.scaffold,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(color: primary, fontSize: 14),
              cursorColor: AppColors.accentOf(context),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索章节名 / 序号',
                hintStyle: TextStyle(color: secondary, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.cancel, size: 16, color: secondary),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

/// Volume header — grouping label only, deliberately not tappable.
class _VolumeTile extends StatelessWidget {
  final String title;
  final int count;
  final Color tertiary;

  const _VolumeTile({
    required this.title,
    required this.count,
    required this.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    final companion = AppColors.companionOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: tertiary,
                  ),
                ),
              ),
              if (count > 0)
                Text(
                  '$count 章',
                  style: TextStyle(fontSize: 11, color: tertiary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: companion.withValues(alpha: .45)),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final int index;
  final String title;

  /// Per-chapter meta from `ruleToc.updateTime` (字数 / 更新时间); empty when
  /// the source has no such rule, in which case the row stays single-line.
  final String info;
  final bool selected;
  final bool cached;
  final bool dark;
  final Color primary;
  final Color tertiary;
  final VoidCallback onTap;

  const _ChapterTile({
    required this.index,
    required this.title,
    this.info = '',
    required this.selected,
    required this.cached,
    required this.dark,
    required this.primary,
    required this.tertiary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final titleColor = selected ? accent : primary;
    final indexColor = selected ? accent : tertiary;

    return Material(
      color: selected
          ? AppColors.accentSoftOf(context)
          : (dark ? AppColors.scaffoldDark : AppColors.scaffold),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: indexColor,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                    if (info.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          info.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tertiary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.menu_book, size: 16, color: accent),
                )
              else if (cached)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '已缓存',
                    style: TextStyle(color: tertiary, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final bool dark;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color divider;
  final bool showToTop;
  final bool reloading;
  final VoidCallback? onReload;
  final VoidCallback? onJumpList;
  final VoidCallback? onJumpChapter;
  final VoidCallback? onLocateCurrent;

  const _BottomBar({
    required this.dark,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.divider,
    required this.showToTop,
    this.reloading = false,
    required this.onReload,
    required this.onJumpList,
    required this.onJumpChapter,
    required this.onLocateCurrent,
  });

  @override
  Widget build(BuildContext context) {
    // 面板底部贴手势条：用 viewPadding（弹层里 padding 可能被框架移除）。
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) {
      final enabled = onTap != null;
      final color = enabled ? primary : secondary.withValues(alpha: 0.45);
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: divider, width: 0.5)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        child: reloading
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '正在重新加载目录…',
                    style: TextStyle(color: secondary, fontSize: 13),
                  ),
                ),
              )
            : Row(
                children: [
                  btn(icon: Icons.refresh, label: '刷新', onTap: onReload),
                  btn(
                    icon: Icons.low_priority,
                    label: '跳转',
                    onTap: onJumpChapter,
                  ),
                  btn(
                    icon: Icons.my_location_outlined,
                    label: '当前',
                    onTap: onLocateCurrent,
                  ),
                  btn(
                    icon: showToTop
                        ? Icons.vertical_align_top
                        : Icons.vertical_align_bottom,
                    label: showToTop ? '顶部' : '底部',
                    onTap: onJumpList,
                  ),
                ],
              ),
      ),
    );
  }
}
