import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/data/entities/book_tag.dart';
import 'package:sqflite/sqflite.dart';

/// Shelf tags: definitions live in `tags`, assignments in `book_tags`.
///
/// Deleting a tag removes its assignments; deleting a book cascades.
/// Every mutation fires [ShelfTagsChanged] so the shelf filter refreshes.
class TagRepository {
  TagRepository({ReaderDatabase? db}) : _db = db ?? ReaderDatabase.instance;

  final ReaderDatabase _db;

  static final TagRepository instance = TagRepository();

  Future<Database> get _database => _db.database;

  Future<List<BookTag>> all() async {
    final db = await _database;
    final rows = await db.query('tags', orderBy: 'created_at ASC, name ASC');
    return rows.map(BookTag.fromRow).toList(growable: false);
  }

  /// Create a tag; returns the existing one when the name already exists.
  Future<BookTag?> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 24) return null;
    final db = await _database;
    final existing = await db.query(
      'tags',
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) return BookTag.fromRow(existing.first);

    final tag = BookTag(
      id: 'tag-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert('tags', {
      'id': tag.id,
      'name': tag.name,
      'created_at': tag.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    eventBus.fire(ShelfTagsChanged());
    return tag;
  }

  /// Rename; returns false when the name is empty, too long or already used.
  Future<bool> rename(String id, String name) async {
    final trimmed = name.trim();
    if (id.isEmpty || trimmed.isEmpty || trimmed.length > 24) return false;
    final db = await _database;
    final clash = await db.query(
      'tags',
      columns: ['id'],
      where: 'name = ? AND id != ?',
      whereArgs: [trimmed, id],
      limit: 1,
    );
    if (clash.isNotEmpty) return false;
    final changed = await db.update(
      'tags',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed > 0) eventBus.fire(ShelfTagsChanged());
    return changed > 0;
  }

  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('book_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
    });
    eventBus.fire(ShelfTagsChanged());
  }

  Future<List<BookTag>> forBook(String bookId) async {
    if (bookId.isEmpty) return const [];
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT t.* FROM tags t JOIN book_tags m ON m.tag_id = t.id '
      'WHERE m.book_id = ? ORDER BY t.created_at ASC, t.name ASC',
      [bookId],
    );
    return rows.map(BookTag.fromRow).toList(growable: false);
  }

  Future<Set<String>> bookIdsForTag(String tagId) async {
    if (tagId.isEmpty) return {};
    final db = await _database;
    final rows = await db.query(
      'book_tags',
      columns: ['book_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    return rows
        .map((r) => r['book_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Replace a book's tag assignments in one transaction.
  Future<void> setForBook(String bookId, Iterable<String> tagIds) async {
    if (bookId.isEmpty) return;
    final ids = tagIds.where((id) => id.isNotEmpty).toSet();
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('book_tags', where: 'book_id = ?', whereArgs: [bookId]);
      for (final tagId in ids) {
        await txn.insert('book_tags', {
          'book_id': bookId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    eventBus.fire(ShelfTagsChanged());
  }

  /// Assignment counts per tag (management page).
  Future<Map<String, int>> counts() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT tag_id, COUNT(*) AS c FROM book_tags GROUP BY tag_id',
    );
    return {
      for (final row in rows)
        row['tag_id']?.toString() ?? '': (row['c'] as num?)?.toInt() ?? 0,
    };
  }
}
