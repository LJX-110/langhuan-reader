import 'package:langhuan/data/entities/book.dart';

/// Display-only book shape shared by the shelf and local 3D shelves.
///
/// Keeping [Bookshelf3D] on this small value object avoids binding the widget
/// to either the online `SearchItem` or the persistent `Book` entity.
class ShelfBookView {
  const ShelfBookView({
    required this.id,
    required this.name,
    required this.author,
    required this.coverUrl,
    this.referer = '',
    this.progressLabel = '',
    this.hasUpdate = false,
  });

  final String id;
  final String name;
  final String author;
  final String coverUrl;
  final String referer;
  final String progressLabel;
  final bool hasUpdate;

  factory ShelfBookView.fromBook(Book book) {
    final chapter = book.readingChapter.trim();
    return ShelfBookView(
      id: book.id,
      name: book.name,
      author: book.author,
      coverUrl: book.coverUrl,
      referer: book.bookUrl,
      progressLabel: chapter.isEmpty ? '未开始阅读' : '读到 · $chapter',
      hasUpdate: book.hasUpdate != 0,
    );
  }
}
