/// One row in the "recently read" list.
class ReadingRecord {
  const ReadingRecord({
    required this.bookId,
    required this.bookName,
    required this.author,
    required this.coverUrl,
    required this.chapterIndex,
    required this.pageIndex,
    required this.chapterName,
    required this.readAt,
  });

  final String bookId;
  final String bookName;
  final String author;
  final String coverUrl;
  final int chapterIndex;
  final int pageIndex;
  final String chapterName;
  final int readAt;

  String get progressLabel {
    final chapter = chapterName.trim();
    final page = '第 ${pageIndex + 1} 页';
    return chapter.isEmpty ? page : '$chapter · $page';
  }

  static ReadingRecord fromRow(Map<String, Object?> row) => ReadingRecord(
    bookId: row['book_id'] as String? ?? '',
    bookName: row['book_name'] as String? ?? '',
    author: row['author'] as String? ?? '',
    coverUrl: row['cover_url'] as String? ?? '',
    chapterIndex: row['chapter_index'] as int? ?? 0,
    pageIndex: row['page_index'] as int? ?? 0,
    chapterName: row['chapter_name'] as String? ?? '',
    readAt: row['read_at'] as int? ?? 0,
  );
}
