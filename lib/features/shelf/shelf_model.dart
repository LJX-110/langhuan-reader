import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/tag_repository.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_tag.dart';
import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:langhuan/design/components/feedback.dart';

enum ShelfFilter { all, reading, unread }

class ShelfModel with ChangeNotifier {
  List<Book> shelf = [];

  ShelfFilter filter = ShelfFilter.all;

  /// Tag definitions and the active tag filter (null = all tags).
  List<BookTag> tags = const [];
  String? activeTagId;
  Set<String> _taggedBookIds = const {};

  /// No schema field for "has read"; chapter/page progress is the signal we
  /// already persist for every book.
  List<Book> get visibleShelf {
    var list = shelf;
    final tagId = activeTagId;
    if (tagId != null) {
      list = list
          .where((b) => _taggedBookIds.contains(b.id))
          .toList(growable: false);
    }
    switch (filter) {
      case ShelfFilter.all:
        return list;
      case ShelfFilter.reading:
        return list
            .where(
              (b) =>
                  b.readingChapter.trim().isNotEmpty ||
                  b.chapterIndex > 0 ||
                  b.pageIndex > 0,
            )
            .toList(growable: false);
      case ShelfFilter.unread:
        return list
            .where(
              (b) =>
                  b.readingChapter.trim().isEmpty &&
                  b.chapterIndex <= 0 &&
                  b.pageIndex <= 0,
            )
            .toList(growable: false);
    }
  }

  /// Reload tag definitions and the active filter's book set.
  Future<void> loadTags() async {
    tags = await TagRepository.instance.all();
    final tagId = activeTagId;
    if (tagId != null && !tags.any((tag) => tag.id == tagId)) {
      activeTagId = null;
      _taggedBookIds = const {};
    } else if (tagId != null) {
      _taggedBookIds = await TagRepository.instance.bookIdsForTag(tagId);
    }
    notifyListeners();
  }

  Future<void> setTag(String? tagId) async {
    if (activeTagId == tagId) return;
    activeTagId = tagId;
    _taggedBookIds = tagId == null
        ? const {}
        : await TagRepository.instance.bookIdsForTag(tagId);
    notifyListeners();
  }

  void setFilter(ShelfFilter value) {
    if (filter == value) return;
    filter = value;
    notifyListeners();
  }

  bool inShelf(Object? id) {
    return shelf.map((f) => f.id).toList().contains(id);
  }

  /// Sync in-memory shelf entry only. DB progress is written by ReadModel.saveData.
  void updReadBookProcess(UpdateBookProcess up) {
    Book? b;
    for (final item in shelf) {
      if (item.id == up.bookId) {
        b = item;
        break;
      }
    }
    if (b == null) return;
    b.chapterIndex = up.cur;
    b.pageIndex = up.index;
    if (up.chapterName.isNotEmpty) {
      b.readingChapter = up.chapterName;
    }
    notifyListeners();
  }

  Future<void> initShelf() async {
    shelf = await _books.getAll(includeLocal: false);
    notifyListeners();
  }

  BuildContext? context;
  final BookRepository _books = BookRepository.instance;

  /// Clear the shelf badge after the user opens the book.
  void markUpdateSeen(String bookId) {
    for (final book in shelf) {
      if (book.id != bookId) continue;
      if (book.hasUpdate == 0) return;
      book.hasUpdate = 0;
      notifyListeners();
      return;
    }
  }

  /// Local-only shelf refresh (no cloud).
  Future<void> refreshShelf() async {
    shelf = await _books.getAll(includeLocal: false);
    notifyListeners();
  }

  /// 书架排序
  Future<void> sort(int i) async {
    var book = shelf[i];
    book.hasUpdate = 0;
    book.sortTime = DateUtil.getNowDateMs();

    shelf.sort((o1, o2) => o2.sortTime.compareTo(o1.sortTime));
    notifyListeners();
    await _books.touchSortTime(book.id);
  }

  //根据id判断书架是否存在本书
  bool isOnShelf(String id) {
    return shelf.map((f) => f.id).toList().contains(id);
  }

  /// Remove one book from the shelf. The row (and with it reading history and
  /// bookmarks) stays in the DB; only `on_shelf` flips to 0.
  Future<void> removeBook(Book book) async {
    shelf = shelf.where((b) => b.id != book.id).toList(growable: false);
    notifyListeners();
    await _books.retire([book.id]);
  }

  /// Remove every book in [ids]; used by the 3D 整理页 batch delete.
  Future<void> removeBooks(Set<String> ids) async {
    if (ids.isEmpty) return;
    shelf = shelf.where((b) => !ids.contains(b.id)).toList(growable: false);
    notifyListeners();
    await _books.retire(ids.toList(growable: false));
  }

  /// Persist a new shelf order after a 3D drag-reorder.
  ///
  /// `sort_time` is rewritten as "newest position first" in one transaction,
  /// so the order survives restarts and the reader's "touch to top" still
  /// works with the same field.
  Future<void> applyOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final byId = <String, Book>{for (final b in shelf) b.id: b};
    final next = <Book>[];
    for (final id in orderedIds) {
      final book = byId.remove(id);
      if (book != null) next.add(book);
    }
    // Defensive: keep rows that were not part of the drag.
    next.addAll(byId.values);
    final base = DateUtil.getNowDateMs();
    for (var i = 0; i < next.length; i++) {
      next[i].sortTime = base - i;
    }
    shelf = next;
    notifyListeners();
    await _books.updateSortOrder(next.map((b) => b.id).toList(growable: false));
  }

  Future<void> modifyShelf(Book book) async {
    var action = shelf.map((f) => f.id).toList().contains(book.id)
        ? 'del'
        : 'add';
    if (action == "add") {
      shelf.insert(0, book);
      await _books.upsertAll([book]);
      // A previously removed book keeps its row (history/bookmarks); flip the
      // flag back so it survives the next cold start.
      await _books.setOnShelf([book.id], true);
      notifyListeners();

      showFeedback("已添加到书架");
    } else if (action == "del") {
      for (var i = 0; i < shelf.length; i++) {
        if (shelf[i].id == book.id) {
          shelf.removeAt(i);
          notifyListeners();
        }
      }
      await _books.retire([book.id]);
      showFeedback("已移除出书架");
    }
  }

  /// No-op: token refresh removed with book backend.
  Future<void> freshToken() async {}
}
