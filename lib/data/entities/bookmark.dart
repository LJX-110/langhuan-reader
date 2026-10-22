/// A saved position inside a book.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.chapterName,
    required this.excerpt,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String chapterName;
  final String excerpt;
  final int createdAt;

  static String idFor(String bookId, int chapterIndex, int pageIndex) =>
      'bm_${bookId}_${chapterIndex}_$pageIndex';

  String get pageLabel => '第 ${pageIndex + 1} 页';

  Map<String, Object?> toRow() => {
    'id': id,
    'book_id': bookId,
    'chapter_index': chapterIndex,
    'page_index': pageIndex,
    'chapter_name': chapterName,
    'excerpt': excerpt,
    'created_at': createdAt,
  };

  static Bookmark fromRow(Map<String, Object?> row) => Bookmark(
    id: row['id'] as String? ?? '',
    bookId: row['book_id'] as String? ?? '',
    chapterIndex: row['chapter_index'] as int? ?? 0,
    pageIndex: row['page_index'] as int? ?? 0,
    chapterName: row['chapter_name'] as String? ?? '',
    excerpt: row['excerpt'] as String? ?? '',
    createdAt: row['created_at'] as int? ?? 0,
  );
}
