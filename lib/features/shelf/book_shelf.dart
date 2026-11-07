import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/perf_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/data/entities/book_tag.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
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
import 'package:langhuan/features/sources/engine/source_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langhuan/design/components/pressable.dart';

/// 书架：只有 3D 书架一种形态；整理页负责排序与批量删除。
class BookShelf extends ConsumerStatefulWidget {
  const BookShelf({super.key});

  @override
  ConsumerState<BookShelf> createState() => _BookShelfState();
}

class _BookShelfState extends ConsumerState<BookShelf> {
  StreamSubscription<ShelfTagsChanged>? _tagsSub;

  @override
  void initState() {
    super.initState();
    _tagsSub = eventBus.on<ShelfTagsChanged>().listen((_) {
      ref.read(shelfModelProvider).loadTags();
    });
    // Cold start: ShelfModel starts empty. Without this the shelf shows
    // nothing until the user re-adds a book (2.1.0 regression).
    final perf = PerfLog.start('Shelf.coldStart');
    ref.read(shelfModelProvider).initShelf().then((_) async {
      perf.done('books=${ref.read(shelfModelProvider).shelf.length}');
      await ref.read(shelfModelProvider).loadTags();
      if (!mounted) return;
      // Fill covers the source never gave us (runs at most once per book).
      if (!SpUtil.getBool(PrefsKeys.lowPerformance)) {
        ShelfCoverEnricher().enrich(
          ref.read(shelfModelProvider).shelf,
          onUpdated: () => ref.read(shelfModelProvider).refreshShelf(),
        );
      }
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

  /// 书架内联搜索：空查询时保留当前筛选，仅按书名 / 作者过滤。
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tagsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shelfModel = ref.watch(shelfModelProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visible = shelfModel.visibleShelf;
    final books = _query.trim().isEmpty
        ? visible
        : visible
              .where((b) => bookMatchesShelfQuery(b, _query))
              .toList(growable: false);
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
                searching: _searching,
                searchController: _searchCtrl,
                query: _query,
                onStartSearch: () => setState(() => _searching = true),
                onQueryChanged: (value) => setState(() => _query = value),
                onCloseSearch: () {
                  _searchCtrl.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _searching = false;
                    _query = '';
                  });
                },
                onGlobalSearch: () {
                  Routes.navigateTo(
                    context,
                    Routes.search,
                    params: {'type': 'book', 'name': _query.trim()},
                  );
                },
                onManage: () => Routes.navigateTo(context, Routes.sortShelf),
                onHistory: () => Routes.navigateTo(context, Routes.history),
                onRandom: () => _openRandom(books),
                tags: shelfModel.tags,
                activeTagId: shelfModel.activeTagId,
                onTag: shelfModel.setTag,
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
                          : _query.trim().isNotEmpty
                          ? EmptyState(
                              title: '没有匹配「${_query.trim()}」的书',
                              hint: '换个书名或作者关键词，或到全网搜索。',
                              alignment: EmptyStateAlignment.left,
                              action: TextButton(
                                onPressed: () {
                                  Routes.navigateTo(
                                    context,
                                    Routes.search,
                                    params: {
                                      'type': 'book',
                                      'name': _query.trim(),
                                    },
                                  );
                                },
                                child: const Text('搜索全网'),
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
                          entryAnimation: !SpUtil.getBool(
                            PrefsKeys.lowPerformance,
                          ),
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

  /// 随机抽书：尊重当前筛选（在读 / 未读 / 全部）。
  void _openRandom(List<Book> books) {
    if (books.isEmpty) return;
    final pick = books[Random().nextInt(books.length)];
    _openShelfBook(ShelfBookView.fromBook(pick));
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
        child: Pressable(
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
                        chapter.isEmpty
                            ? '第 ${book.chapterIndex + 1} 章'
                            : chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_outline, size: 26, color: accent),
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
    final model = ref.read(shelfModelProvider);
    for (final book in model.shelf) {
      if (book.id == view.id) {
        openBook = book;
        break;
      }
    }
    // 打开即认为已看到更新，清掉书架角标（DB 同步）。
    if (openBook.hasUpdate != 0) {
      openBook.hasUpdate = 0;
      unawaited(BookRepository.instance.setHasUpdate(openBook.id, 0));
      model.markUpdateSeen(openBook.id);
    }
    // 立即推页：持久化进度由阅读器 hydrateReadingSession 自行与 DB 合并
    // （reading_session_opener.dart:79-98），此处不再等待一次 DB 往返。
    await Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(openBook.toJson())},
    );
  }

  /// 手动检查单本更新：只查本书源，不扫全库。
  Future<void> _checkUpdate(Book book) async {
    if (Book.isLocalSource(book.sourceUrl)) return;
    final source = await SourceRepository.instance.getByUrl(book.sourceUrl);
    if (!mounted) return;
    if (source == null) {
      showError('书源不存在：${book.originName}');
      return;
    }
    try {
      final toc = await SourceEngine.instance.toc(
        source,
        book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl,
        bookUrl: book.bookUrl,
        bookName: book.name,
      );
      final readable = toc
          .where((c) => !c.isVolume && c.name.trim().isNotEmpty)
          .toList(growable: false);
      if (readable.isEmpty) {
        showError('目录为空，暂无法检查更新');
        return;
      }
      final latest = readable.last.name.trim();
      final old = book.latestChapter.trim();
      final changed = shelfHasNewChapter(oldLatest: old, newLatest: latest);
      await BookRepository.instance.updateLatestChapter(
        bookId: book.id,
        latestChapter: latest,
        hasUpdate: changed ? 1 : 0,
        updatedAt: DateTime.now().toIso8601String(),
      );
      if (!mounted) return;
      showFeedback(
        changed ? '发现更新：$latest' : (old.isEmpty ? '最新章节：$latest' : '已是最新章节'),
      );
      await ref.read(shelfModelProvider).refreshShelf();
    } catch (_) {
      if (!mounted) return;
      showError('检查更新失败，请稍后重试');
    }
  }

  /// 长按书脊：操作菜单（查看详情 / 检查更新 / 移出书架）。
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
            if (!Book.isLocalSource(target!.sourceUrl))
              ListTile(
                leading: Icon(
                  Icons.sync,
                  size: 20,
                  color: AppColors.accentOf(ctx),
                ),
                title: const Text('检查更新', style: TextStyle(fontSize: 15)),
                onTap: () => Navigator.pop(ctx, 'update'),
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
    } else if (action == 'update') {
      await _checkUpdate(target);
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
    AppLog.i('Shelf', 'remove book=${removed.id} 「${removed.name}」');
    // 可撤销：retire 只是 on_shelf 置 0，撤回即恢复（对齐文库的撤销反馈）。
    showFeedback(
      '已移除《${removed.name}》',
      context: context,
      actionLabel: '撤销',
      onAction: () => _undoRemove(removed, model),
    );
  }

  Future<void> _undoRemove(Book removed, ShelfModel model) async {
    AppLog.i('Shelf', 'undo remove book=${removed.id}');
    await BookRepository.instance.setOnShelf([removed.id], true);
    await model.initShelf();
  }
}

/// 书架角标判定：已知旧章节非空且与最新章节不同。
bool shelfHasNewChapter({
  required String oldLatest,
  required String newLatest,
}) {
  final old = oldLatest.trim();
  final latest = newLatest.trim();
  return old.isNotEmpty && latest.isNotEmpty && latest != old;
}

/// 书架内联搜索匹配：书名或作者包含关键词（忽略大小写与首尾空白）。
bool bookMatchesShelfQuery(Book book, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return book.name.toLowerCase().contains(q) ||
      book.author.toLowerCase().contains(q);
}

/// 顶栏：标题 + 随机 / 阅读记录 / 整理（不再有网格 / 列表切换）
class _ShelfHeader extends StatelessWidget {
  final ShelfFilter filter;
  final ValueChanged<ShelfFilter> onFilter;
  final bool searching;
  final TextEditingController searchController;
  final String query;
  final VoidCallback onStartSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCloseSearch;
  final VoidCallback onGlobalSearch;
  final VoidCallback onManage;
  final VoidCallback onHistory;
  final VoidCallback onRandom;
  final List<BookTag> tags;
  final String? activeTagId;
  final ValueChanged<String?> onTag;

  const _ShelfHeader({
    required this.filter,
    required this.onFilter,
    required this.searching,
    required this.searchController,
    required this.query,
    required this.onStartSearch,
    required this.onQueryChanged,
    required this.onCloseSearch,
    required this.onGlobalSearch,
    required this.onManage,
    required this.onHistory,
    required this.onRandom,
    required this.tags,
    required this.activeTagId,
    required this.onTag,
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
                icon: Icons.casino_outlined,
                tooltip: '随机一本',
                onTap: onRandom,
              ),
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
            child: searching
                ? Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: dark
                                ? AppColors.surfaceDark
                                : AppColors.paperLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: dark
                                  ? AppColors.dividerDark
                                  : AppColors.line,
                              width: .5,
                            ),
                          ),
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            onChanged: onQueryChanged,
                            textInputAction: TextInputAction.search,
                            style: TextStyle(
                              fontSize: 13,
                              color: dark
                                  ? AppColors.textOnDark
                                  : AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '搜索书架：书名 / 作者',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: dark
                                    ? AppColors.textMutedDark
                                    : AppColors.inkMute,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 16,
                                color: dark
                                    ? AppColors.textMutedDark
                                    : AppColors.inkMute,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 34,
                              ),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清空',
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        searchController.clear();
                                        onQueryChanged('');
                                      },
                                    ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: onGlobalSearch,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text('全网', style: TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        tooltip: '关闭书架搜索',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: onCloseSearch,
                      ),
                    ],
                  )
                : PaperSearchEntry(onTap: onStartSearch, hint: '搜索书架或全网书籍'),
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
                      child: Pressable(
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
          if (tags.isNotEmpty)
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                children: [
                  _tagChip(
                    dark,
                    accent,
                    '全部',
                    activeTagId == null,
                    () => onTag(null),
                  ),
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _tagChip(
                        dark,
                        accent,
                        tag.name,
                        activeTagId == tag.id,
                        () => onTag(tag.id),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tagChip(
    bool dark,
    Color accent,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accent : line, width: .5),
          color: selected ? accent.withValues(alpha: .08) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, color: selected ? accent : muted),
        ),
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
