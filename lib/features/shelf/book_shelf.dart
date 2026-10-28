import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/core/utils/perf_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/page_header.dart';
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
              Expanded(
                child: books.isEmpty
                    ? (shelfModel.shelf.isEmpty
                          ? _EmptyShelf(dark: dark)
                          : _EmptyFilter(
                              onShowAll: () =>
                                  shelfModel.setFilter(ShelfFilter.all),
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
                        ),
                      ),
              ),
            ],
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
    // Prefer durable DB progress over possibly-stale in-memory shelf data.
    try {
      final dbBook = await BookRepository.instance.getById(view.id);
      if (dbBook != null) openBook = dbBook;
    } catch (_) {}
    if (!mounted) return;
    await Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(openBook.toJson())},
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
    BotToast.showText(text: '已移除《${target.name}》');
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '书架还是空的',
            style: TextStyle(
              color: primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '去发现页或搜索找一本书。',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextButton(
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
        ],
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '这个筛选下还没有书',
            style: TextStyle(
              color: primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onShowAll, child: const Text('查看全部')),
        ],
      ),
    );
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
                          duration: const Duration(milliseconds: 160),
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
                                duration: const Duration(milliseconds: 160),
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
