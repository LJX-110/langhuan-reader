import 'package:bot_toast/bot_toast.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书架整理：与书架相同的 3D 形态，负责排序与批量删除。
///
/// - 点击书本切换选中（书卡右下角出现勾选）；
/// - 长按拾起、左右拖动调整顺序，松手落位并写回 `sortTime`；
/// - 底部栏显示已选数量并批量删除，删除前在栏内二次确认。
class SortShelf extends ConsumerStatefulWidget {
  const SortShelf({super.key});

  @override
  ConsumerState<SortShelf> createState() => _SortShelfState();
}

class _SortShelfState extends ConsumerState<SortShelf> {
  final Set<String> _selected = <String>{};
  bool _confirming = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(shelfModelProvider);
    final books = model.shelf;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allPicked = books.isNotEmpty && _selected.length == books.length;

    return Scaffold(
      backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffold,
      appBar: AppBar(
        title: const Text('书架整理'),
        leadingWidth: 80,
        leading: TextButton(
          onPressed: books.isEmpty
              ? null
              : () => setState(() {
                  if (allPicked) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(books.map((b) => b.id));
                  }
                  _confirming = false;
                }),
          child: Text(allPicked ? '全不选' : '全选'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Text(
                '书架是空的，先去加几本书。',
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? AppColors.textMutedDark : AppColors.inkMute,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: Bookshelf3D(
                books: books
                    .map(ShelfBookView.fromBook)
                    .toList(growable: false),
                initialBookId: _initialFocusId(books),
                onOpen: (_) {},
                selectable: true,
                selectedIds: _selected,
                onToggleSelect: (view) => setState(() {
                  if (!_selected.remove(view.id)) _selected.add(view.id);
                  _confirming = false;
                }),
                onReorder: _reorder,
              ),
            ),
      bottomNavigationBar: SafeArea(top: false, child: _bottomBar(dark)),
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

  Widget _bottomBar(bool dark) {
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    if (_confirming) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '删除所选 ${_selected.length} 本？删除后无法恢复。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            TextButton(
              onPressed: _deleting
                  ? null
                  : () => setState(() => _confirming = false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: _deleting ? null : _deleteSelected,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: _deleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('删除'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selected.isEmpty
                  ? '点击书本选择，长按拖动排序'
                  : '已选 ${_selected.length} 本',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => setState(() => _confirming = true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final model = ref.read(shelfModelProvider);
    final ids = model.shelf.map((b) => b.id).toList(growable: true);
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    await model.applyOrder(ids);
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) return;
    setState(() => _deleting = true);
    final count = _selected.length;
    try {
      await ref.read(shelfModelProvider).removeBooks(Set.of(_selected));
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _confirming = false;
        _deleting = false;
      });
      BotToast.showText(text: '已删除 $count 本');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      BotToast.showText(text: '删除失败：${Redact.userMessage(e)}');
    }
  }
}
