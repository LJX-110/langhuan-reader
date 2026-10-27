import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:sqflite/sqflite.dart';

/// Shelf + reading progress persistence.
class BookRepository {
  BookRepository({ReaderDatabase? db}) : _db = db ?? ReaderDatabase.instance;

  final ReaderDatabase _db;

  static final BookRepository instance = BookRepository();

  Future<Database> get _database => _db.database;

  Future<List<Book>> getAll({bool includeLocal = true}) async {
    final db = await _database;
    final rows = await db.query(
      'books',
      // `on_shelf = 0` rows stay in the table so reading history and
      // bookmarks survive a "移出书架"; they just do not show in the grid.
      where: includeLocal
          ? null
          : 'on_shelf = 1 AND source_url NOT LIKE ?',
      whereArgs: includeLocal ? null : ['${Book.localSourcePrefix}%'],
      orderBy: 'sort_time DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Book>> getLocal() async {
    final db = await _database;
    final rows = await db.query(
      'books',
      where: 'source_url LIKE ?',
      whereArgs: ['${Book.localSourcePrefix}%'],
      orderBy: 'sort_time DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Book?> getById(String id) async {
    final db = await _database;
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<bool> exists(String id) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT 1 AS ok FROM books WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(Book book) async {
    final db = await _database;
    await db.insert(
      'books',
      _toRow(book),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<Book> books) async {
    if (books.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final b in books) {
      batch.insert(
        'books',
        _toRow(b),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Insert only if missing (first open / history). A missing row means the
  /// book is not on the shelf, so it is inserted as off-shelf.
  Future<void> ensureExists(Book book) async {
    if (await exists(book.id)) return;
    final db = await _database;
    await db.insert(
      'books',
      _toRow(book, onShelf: 0),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> saveProgress({
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    double scrollOffset = 0,
    String? readingChapter,
  }) async {
    final db = await _database;
    final values = <String, Object?>{
      'chapter_index': chapterIndex,
      'page_index': pageIndex,
      'scroll_offset': scrollOffset,
    };
    if (readingChapter != null) {
      values['reading_chapter'] = readingChapter;
    }
    return db.update('books', values, where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> updateSource({
    required String bookId,
    required String sourceUrl,
    required String bookUrl,
    required String originName,
    required String tocUrl,
  }) async {
    final db = await _database;
    await db.update(
      'books',
      {
        'source_url': sourceUrl,
        'book_url': bookUrl,
        'origin_name': originName,
        'toc_url': tocUrl,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updateLatestChapter({
    required String bookId,
    String? latestChapter,
    int? hasUpdate,
    String? updatedAt,
    String? coverUrl,
  }) async {
    final db = await _database;
    final values = <String, Object?>{};
    if (latestChapter != null) values['latest_chapter'] = latestChapter;
    if (hasUpdate != null) values['has_update'] = hasUpdate;
    if (updatedAt != null) values['updated_at'] = updatedAt;
    if (coverUrl != null) values['cover_url'] = coverUrl;
    if (values.isEmpty) return;
    await db.update('books', values, where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> setHasUpdate(String bookId, int hasUpdate) async {
    final db = await _database;
    await db.update(
      'books',
      {'has_update': hasUpdate},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> touchSortTime(String bookId) async {
    final db = await _database;
    await db.update(
      'books',
      {'sort_time': DateUtil.getNowDateMs(), 'has_update': 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Persist a full shelf order: `sort_time` descends with the list position.
  ///
  /// One transaction; only `sort_time` is written so progress, source and
  /// reading state stay untouched.
  Future<void> updateSortOrder(List<String> bookIds) async {
    if (bookIds.isEmpty) return;
    final db = await _database;
    final base = DateUtil.getNowDateMs();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < bookIds.length; i++) {
        batch.update(
          'books',
          {'sort_time': base - i},
          where: 'id = ?',
          whereArgs: [bookIds[i]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> delete(String bookId) async {
    final db = await _database;
    // chapters cascade via FK if enabled; also explicit for safety.
    await db.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  /// Persist a cover discovered after the book row was created.
  Future<void> updateCover(String bookId, String coverUrl) async {
    if (bookId.isEmpty || coverUrl.isEmpty) return;
    final db = await _database;
    await db.update(
      'books',
      {'cover_url': coverUrl},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Flip the shelf flag without touching any other column.
  Future<void> setOnShelf(List<String> bookIds, bool onShelf) async {
    if (bookIds.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final id in bookIds) {
      batch.update(
        'books',
        {'on_shelf': onShelf ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Move books off the shelf without deleting the rows.
  ///
  /// Reading history, bookmarks and progress all key off `books.id`, so a hard
  /// delete silently wiped them (2.1.0). Chapter bodies are dropped to reclaim
  /// space; they are re-fetched if the book is added again.
  Future<void> retire(List<String> bookIds) async {
    if (bookIds.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final id in bookIds) {
      batch.update(
        'books',
        {'on_shelf': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      batch.delete('chapters', where: 'book_id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Book _fromRow(Map<String, Object?> row) {
    String s(Object? v) {
      if (v == null) return '';
      final t = v.toString();
      return t == 'null' ? '' : t;
    }

    final latest = s(row['latest_chapter']);
    final reading = s(row['reading_chapter']);
    return Book(
      id: s(row['id']),
      name: s(row['name']),
      author: s(row['author']),
      coverUrl: s(row['cover_url']),
      category: s(row['category']),
      description: s(row['description']),
      // Keep "never opened" distinct from "latest chapter known".
      readingChapter: reading,
      latestChapter: latest,
      chapterIndex: row['chapter_index'] as int? ?? 0,
      pageIndex: row['page_index'] as int? ?? 0,
      scrollOffset: (row['scroll_offset'] as num?)?.toDouble() ?? 0,
      sortTime: row['sort_time'] as int? ?? 0,
      hasUpdate: row['has_update'] as int? ?? 0,
      updatedAt: s(row['updated_at']),
      sourceUrl: s(row['source_url']),
      bookUrl: s(row['book_url']),
      originName: s(row['origin_name']),
      tocUrl: s(row['toc_url']),
    );
  }

  Map<String, Object?> _toRow(Book book, {int onShelf = 1}) {
    return {
      'id': book.id,
      'name': book.name,
      'author': book.author,
      'cover_url': book.coverUrl,
      'category': book.category,
      'description': book.description,
      'source_url': book.sourceUrl,
      'book_url': book.bookUrl,
      'origin_name': book.originName,
      'toc_url': book.tocUrl,
      'chapter_index': book.chapterIndex,
      'page_index': book.pageIndex,
      'scroll_offset': book.scrollOffset,
      'reading_chapter': book.readingChapter,
      'latest_chapter': book.latestChapter.isNotEmpty
          ? book.latestChapter
          : book.readingChapter,
      'sort_time': book.sortTime == 0 ? DateUtil.getNowDateMs() : book.sortTime,
      'has_update': book.hasUpdate,
      'updated_at': book.updatedAt,
      'on_shelf': onShelf,
    };
  }
}
