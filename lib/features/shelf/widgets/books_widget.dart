import 'dart:convert';

import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/features/shelf/widgets/has_update_icon_img.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooksWidget extends ConsumerStatefulWidget {
  final String type;

  const BooksWidget(this.type, {super.key});

  @override
  ConsumerState<BooksWidget> createState() => _BooksWidgetState();
}

class _BooksWidgetState extends ConsumerState<BooksWidget> {
  late ShelfModel _shelfModel;
  late bool isShelf;

  final double aspectRatioList = 0.69;
  final double aspectRatioCover = AppDimens.coverAspect;

  @override
  void initState() {
    super.initState();
    isShelf = widget.type == '';
    _shelfModel = ref.read(shelfModelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shelfModel.context = context;
      if (isShelf && _shelfModel.shelf.isEmpty) {
        _shelfModel.initShelf();
      }
    });
  }

  int get _columns => Screen.width >= 600 ? 3 : 2;

  List<Book> get _books =>
      isShelf ? _shelfModel.visibleShelf : _shelfModel.shelf;

  double get _coverWidth {
    final pad = AppDimens.pagePadding * 2;
    final gaps = AppDimens.shelfSpacing * (_columns - 1);
    return (Screen.width - pad - gaps) / _columns;
  }

  double get _coverHeight => _coverWidth / aspectRatioCover;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _primary => _dark ? AppColors.textOnDark : AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    _shelfModel = ref.watch(shelfModelProvider);
    if (_books.isEmpty) {
      if (isShelf && _shelfModel.shelf.isNotEmpty) return _emptyFilter();
      return _emptyShelf();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: _shelfModel.cover ? coverModel() : listModel(),
    );
  }

  Widget _emptyShelf() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '书架还是空的',
            style: TextStyle(
              color: _primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '去发现页或搜索找一本书。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
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

  Widget _emptyFilter() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '这个筛选下还没有书',
            style: TextStyle(
              color: _primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _shelfModel.setFilter(ShelfFilter.all),
            child: const Text('查看全部'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cover grid
  // ---------------------------------------------------------------------------

  Widget coverModel() {
    final w = _coverWidth;
    final h = _coverHeight;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    return GridView.builder(
      padding: const EdgeInsets.only(top: 14, bottom: 28),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        crossAxisSpacing: AppDimens.shelfSpacing,
        mainAxisSpacing: AppDimens.shelfRunSpacing,
        // cover + title + author + progress
        childAspectRatio: w / (h + 78),
      ),
      itemCount: _books.length,
      itemBuilder: (context, i) {
        final book = _books[i];
        return bookAction(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                  boxShadow: AppShadows.cover,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                  child: HasUpdateIconImg(
                    book: book,
                    width: w,
                    height: h,
                    sorting: widget.type == 'sort',
                    picked: widget.type == 'sort' && _shelfModel.picks(i),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _titleLabel(book),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _primary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _authorLabel(book),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: secondaryText),
              ),
              const SizedBox(height: 2),
              Text(
                _progressLabel(book),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: secondaryText),
              ),
            ],
          ),
          i,
        );
      },
    );
  }

  String _progressLabel(Book book) {
    final chapter = book.readingChapter.trim();
    if (chapter.isEmpty || chapter == 'null') return '未开始阅读';
    return '读到 · $chapter';
  }

  String _authorLabel(Book book) {
    final a = book.author.trim();
    if (a.isEmpty || a == 'null') return '佚名';
    return a;
  }

  String _titleLabel(Book book) {
    final n = book.name.trim();
    if (n.isEmpty || n == 'null') return '未知书名';
    return n;
  }

  Widget bookAction(Widget child, int i) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          widget.type == 'sort' ? _shelfModel.changePick(i) : await readBook(i);
        },
        onLongPress: () {
          Routes.navigateTo(context, Routes.sortShelf);
        },
        child: child,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List mode
  // ---------------------------------------------------------------------------

  Widget listModel() {
    final w = _coverWidth * 0.9;
    final h = w / aspectRatioList;
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: _books.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: w + 16,
        color: _dark ? AppColors.dividerDark : AppColors.divider,
      ),
      itemBuilder: (c, i) => bookAction(getBookItemView(i, w, h), i),
    );
  }

  Future<void> readBook(int i) async {
    final b = _books[i];
    // Prefer durable DB progress over possibly-stale in-memory shelf object.
    Book openBook = b;
    try {
      final dbBook = await BookRepository.instance.getById(b.id);
      if (dbBook != null) {
        openBook = dbBook;
        // Keep shelf row in sync for labels / next open.
        b.chapterIndex = dbBook.chapterIndex;
        b.pageIndex = dbBook.pageIndex;
        b.scrollOffset = dbBook.scrollOffset;
        if (dbBook.readingChapter.isNotEmpty) {
          b.readingChapter = dbBook.readingChapter;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(openBook)},
    );
    _shelfModel.sort(i);
  }

  Widget getBookItemView(int i, double coverW, double coverH) {
    final item = _books[i];
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _shelfModel.modifyShelf(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        height: coverH + 20,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                boxShadow: AppShadows.cover,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                child: HasUpdateIconImg(
                  book: item,
                  width: coverW,
                  height: coverH,
                  sorting: widget.type == 'sort',
                  picked: widget.type == 'sort' && _shelfModel.picks(i),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _titleLabel(item),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _authorLabel(item),
                      style: TextStyle(fontSize: 12, color: secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _progressLabel(item),
                      style: TextStyle(fontSize: 12, color: secondaryText),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (item.updatedAt.isNotEmpty &&
                        item.updatedAt != 'null') ...[
                      const SizedBox(height: 4),
                      Text(
                        item.updatedAt,
                        style: TextStyle(color: secondaryText, fontSize: 11),
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
