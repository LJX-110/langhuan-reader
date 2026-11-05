import 'dart:async';
import 'dart:convert';

import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/core/utils/perf_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/empty_state.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/page_header.dart';
import 'package:langhuan/design/motion.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/platform/system_ui.dart';
import 'package:langhuan/features/shelf/shelf_cover_enricher.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书架：只有 3D 书架一种形态；整理页负责排序与批量删除。
class BookShelf extends ConsumerStatefulWidget {
  const BookShelf({super.key});

  @override
  ConsumerState<BookShelf> createState() => _BookShelfState();
}

class _BookShelfState extends ConsumerState<BookShelf> {
  @override
  void initState() {
    super.initState();
    // Cold start: ShelfModel starts empty. Without this the shelf shows
    // nothing until the user re-adds a book (2.1.0 regression).
    final perf = PerfLog.start('Shelf.coldStart');
    ref.read(shelfModelProvider).initShelf().then((_) {
      perf.done('books=${ref.read(shelfModelProvider).shelf.length}');
      if (!mounted) return;
      // Fill covers the source never gave us (runs at most once per book).
      ShelfCoverEnricher().enrich(
        ref.read(shelfModelProvider).shelf,
        onUpdated: () => ref.read(shelfModelProvider).refreshShelf(),
      );
    });
    if (!SpUtil.containsKey(PrefsKeys.topSafeHeight)) {
      SpUtil.putDouble(PrefsKeys.topSafeHeight, Screen.topSafeHeight);
    }
    if (!SpUtil.containsKey(PrefsKeys.shimmerNums)) {
      SpUtil.putInt(
        PrefsKeys.shimmerNums,
        (Screen.height - Screen.topSafeHeight - Screen.bottomSafeHeight - 60) ~/
            25,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelfModel = ref.watch(shelfModelProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final books = shelfModel.visibleShelf;
    final resume = _resumeBook(books);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiHelper.overlayStyle(context),
      child: Scaffold(
        backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffold,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ShelfHeader(
                filter: shelfModel.filter,
                onFilter: shelfModel.setFilter,
                onSearch: () {
                  Routes.navigateTo(
                    context,
                    Routes.search,
                    params: {'type': 'book', 'name': ''},
                  );
                },
                onManage: () => Routes.navigateTo(context, Routes.sortShelf),
                onHistory: () => Routes.navigateTo(context, Routes.history),
              ),
              if (resume != null) _continueCard(context, resume, dark),
              Expanded(
                child: books.isEmpty
                    ? (shelfModel.shelf.isEmpty
                          ? EmptyState(
                              title: '书架还是空的',
                              hint: '去发现页或搜索找一本书。',
                              alignment: EmptyStateAlignment.left,
                              action: TextButton(
                                onPressed: () {
                                  Routes.navigateTo(
                                    context,
                                    Routes.search,
                                    params: {'type': 'book', 'name': ''},
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text('去搜索'),
                              ),
                            )
                          : EmptyState(
                              title: '这个筛选下还没有书',
                              action: TextButton(
                                onPressed: () =>
                                    shelfModel.setFilter(ShelfFilter.all),
                                child: const Text('查看全部'),
                              ),
                            ))
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.pagePadding,
                        ),
                        child: Bookshelf3D(
                          books: books
                              .map(ShelfBookView.fromBook)
                              .toList(growable: false),
                          initialBookId: _initialFocusId(books),
                          onOpen: _openShelfBook,
                          onDelete: _deleteShelfBook,
                          onLongPress: _longPressShelfBook,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 最近在读的一本（书架已按 `sort_time` 倒序，第一本有进度的就是）。
  Book? _resumeBook(List<Book> books) {
    for (final book in books) {
      if (book.readingChapter.trim().isNotEmpty ||
          book.chapterIndex > 0 ||
          book.pageIndex > 0) {
        return book;
      }
    }
    return null;
  }

  /// 「继续阅读」卡片：封面 + 书名 + 当前章节，点一下直接续读。
  Widget _continueCard(BuildContext context, Book book, bool dark) {
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final surface = dark ? AppColors.scaffoldDark : AppColors.paper;
    final accent = AppColors.accentOf(context);
    final chapter = book.readingChapter.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        4,
        AppDimens.pagePadding,
        10,
      ),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openShelfBook(ShelfBookView.fromBook(book)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Hero(
                  tag: 'cover-${book.name}|${book.author}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: PicWidget(
                      book.coverUrl,
                      height: 64,
                      width: 46,
                      referer: book.bookUrl,
                      title: book.name,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '继续阅读',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.isEmpty ? '第 ${book.chapterIndex + 1} 章' : chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_fill, size: 26, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Default focus: the most recently read book, else the first one.
  String? _initialFocusId(List<Book> books) {
    for (final book in books) {
      if (book.readingChapter.trim().isNotEmpty ||
          book.chapterIndex > 0 ||
          book.pageIndex > 0) {
        return book.id;
      }
    }
    return books.isEmpty ? null : books.first.id;
  }

  Future<void> _openShelfBook(ShelfBookView view) async {
    var openBook = Book.id(view.id);
    for (final book in ref.read(shelfModelProvider).shelf) {
      if (book.id == view.id) {
        openBook = book;
        break;
      }
    }
    // 立即推页：持久化进度由阅读器 hydrateReadingSession 自行与 DB 合并
    // （reading_session_opener.dart:79-98），此处不再等待一次 DB 往返。
    await Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(openBook.toJson())},
    );
  }

  /// 长按书脊：操作菜单（查看详情 / 移出书架）。整理页由拖动排序占用长按。
  Future<void> _longPressShelfBook(ShelfBookView view) async {
    final model = ref.read(shelfModelProvider);
    Book? target;
    for (final book in model.shelf) {
      if (book.id == view.id) {
        target = book;
        break;
      }
    }
    if (target == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    final dark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: dark ? AppColors.surfaceDark : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.accentOf(ctx),
              ),
              title: const Text('查看详情', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'detail'),
            ),
            ListTile(
              leading: Icon(
                Icons.bookmark_remove_outlined,
                size: 20,
                color: AppColors.accentOf(ctx),
              ),
              title: const Text('移出书架', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'detail') {
      _openShelfDetail(target);
    } else if (action == 'remove') {
      await _deleteShelfBook(view);
    }
  }

  /// 从书架直接进详情页（无需网络：书架数据转 BookInfo 种子）。
  void _openShelfDetail(Book book) {
    final info = BookInfo(
      id: book.id,
      name: book.name,
      author: book.author,
      coverUrl: book.coverUrl,
      category: book.category,
      description: book.description,
      latestChapter: book.latestChapter,
      updatedAt: book.updatedAt,
      sourceUrl: book.sourceUrl,
      bookUrl: book.bookUrl,
      originName: book.originName,
      tocUrl: book.tocUrl,
    );
    Routes.navigateTo(
      context,
      Routes.detail,
      params: {'detail': jsonEncode(info.toJson())},
    );
  }

  Future<void> _deleteShelfBook(ShelfBookView view) async {
    final model = ref.read(shelfModelProvider);
    Book? target;
    for (final book in model.shelf) {
      if (book.id == view.id) {
        target = book;
        break;
      }
    }
    if (target == null) return;
    await model.removeBook(target);
    if (!mounted) return;
    final removed = target;
    // 可撤销：retire 只是 on_shelf 置 0，撤回即恢复（对齐文库的撤销反馈）。
    showFeedback(
      context,
      '已移除《${removed.name}》',
      actionLabel: '撤销',
      onAction: () => _undoRemove(removed, model),
    );
  }

  Future<void> _undoRemove(Book removed, ShelfModel model) async {
    await BookRepository.instance.setOnShelf([removed.id], true);
    await model.initShelf();
  }
}

/// 顶栏：标题 + 阅读记录 + 整理（不再有网格 / 列表切换）
class _ShelfHeader extends StatelessWidget {
  final ShelfFilter filter;
  final ValueChanged<ShelfFilter> onFilter;
  final VoidCallback onSearch;
  final VoidCallback onManage;
  final VoidCallback onHistory;

  const _ShelfHeader({
    required this.filter,
    required this.onFilter,
    required this.onSearch,
    required this.onManage,
    required this.onHistory,
  });

  String _filterLabel(ShelfFilter value) {
    switch (value) {
      case ShelfFilter.all:
        return '全部';
      case ShelfFilter.reading:
        return '在读';
      case ShelfFilter.unread:
        return '未读';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;
    final accent = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);

    return Container(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: '书架',
            actions: [
              _HeaderIcon(
                icon: Icons.history,
                tooltip: '阅读记录',
                onTap: onHistory,
              ),
              _HeaderIcon(
                icon: Icons.checklist_rtl,
                tooltip: '书架整理',
                onTap: onManage,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: PaperSearchEntry(onTap: onSearch, hint: '搜索书架或全网书籍'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                for (final value in ShelfFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onFilter(value),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: AppMotion.contact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: filter == value
                                ? accent.withValues(alpha: .10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _filterLabel(value),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: filter == value
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: filter == value
                                      ? accent
                                      : (dark
                                            ? AppColors.textMutedDark
                                            : AppColors.inkMute),
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: AppMotion.contact,
                                width: 16,
                                height: 2,
                                color: filter == value
                                    ? companion
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 22,
        color: dark ? AppColors.textOnDark : AppColors.textPrimary,
      ),
    );
  }
}
