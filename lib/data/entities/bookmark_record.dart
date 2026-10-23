import 'package:langhuan/data/entities/bookmark.dart';

/// A bookmark joined with its book's display fields.
class BookmarkRecord {
  const BookmarkRecord({
    required this.bookmark,
    required this.bookName,
    required this.coverUrl,
    required this.bookUrl,
  });

  final Bookmark bookmark;
  final String bookName;
  final String coverUrl;
  final String bookUrl;

  static BookmarkRecord fromRow(Map<String, Object?> row) => BookmarkRecord(
    bookmark: Bookmark.fromRow(row),
    bookName: row['book_name'] as String? ?? '',
    coverUrl: row['cover_url'] as String? ?? '',
    bookUrl: row['book_url'] as String? ?? '',
  );
}
