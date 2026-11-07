/// A user-defined shelf tag.
class BookTag {
  const BookTag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int createdAt;

  static BookTag fromRow(Map<String, Object?> row) => BookTag(
    id: row['id'] as String? ?? '',
    name: row['name'] as String? ?? '',
    createdAt: row['created_at'] as int? ?? 0,
  );
}
