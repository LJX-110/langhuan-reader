import 'package:langhuan/features/sources/util/book_id.dart';

/// Pure mappings from the legacy multi-file schema to the current reader schema.
///
/// The old databases used different column names than the current tables
/// (`book_id`/`img`/`intro`/`cur`/`idx`/`content`). Copying only the column-name
/// intersection silently dropped every row whose primary key or unique index
/// could not be filled. Each mapper here converts one legacy row explicitly and
/// returns `null` when the row has no usable identity; callers treat that as a
/// hard failure instead of counting it as migrated.
class LegacySchemaMapping {
  LegacySchemaMapping._();

  static Map<String, Object?>? book(Map<String, Object?> row) {
    final id = stringOf(row, const ['id', 'book_id']);
    if (id.isEmpty) return null;
    return {
      'id': id,
      'name': stringOf(row, const ['name']),
      'author': stringOf(row, const ['author']),
      'cover_url': stringOf(row, const ['cover_url', 'img']),
      'category': stringOf(row, const ['category']),
      'description': stringOf(row, const ['description', 'intro']),
      'source_url': stringOf(row, const ['source_url']),
      'book_url': stringOf(row, const ['book_url']),
      'origin_name': stringOf(row, const ['origin_name']),
      'toc_url': stringOf(row, const ['toc_url']),
      'chapter_index': intOf(row, const ['chapter_index', 'cur']),
      'page_index': intOf(row, const ['page_index', 'idx']),
      'scroll_offset': doubleOf(row, const ['scroll_offset', 'position']),
      'reading_chapter': stringOf(row, const ['reading_chapter']),
      // Upstream used newChapter/lastChapter for the newest chapter title.
      'latest_chapter': stringOf(row, const [
        'latest_chapter',
        'newChapter',
        'lastChapter',
      ]),
      'sort_time': intOf(row, const ['sort_time', 'sortTime', 'utime']),
      'has_update': 0,
      'updated_at': stringOf(row, const ['updated_at']),
    };
  }

  /// [ord] is a caller-assigned, per-book, collision-free order. The legacy
  /// `idx` is only an ordering hint; normalising it to a rank keeps
  /// `UNIQUE(book_id, ord)` satisfiable even when old indexes repeat.
  static Map<String, Object?>? chapter(
    Map<String, Object?> row, {
    required int ord,
  }) {
    final bookId = stringOf(row, const ['book_id', 'bookId']);
    if (bookId.isEmpty) return null;
    final url = stringOf(row, const ['url', 'chapter_url']);
    final title = stringOf(row, const ['title', 'name']);
    final body = stringOf(row, const ['body', 'content']);
    final id = url.isNotEmpty ? makeChapterId(bookId, url) : '${bookId}_$ord';
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'url': url,
      'source_url': stringOf(row, const ['source_url']),
      'ord': ord,
      'body': body,
      'has_body': body.isNotEmpty
          ? 1
          : (intOf(row, const ['has_body', 'hasContent']) > 0 ? 1 : 0),
      'content_len': body.isNotEmpty
          ? body.length
          : intOf(row, const ['content_len']),
      // Old page layouts are not ABI-compatible with the current reader;
      // keeping the body and repaginating is safer than loading stale pages.
      'pages_json': null,
      'layout_fp': null,
      'pages_cached_at': 0,
    };
  }

  static Map<String, Object?>? source(Map<String, Object?> row) {
    final url = stringOf(row, const ['book_source_url']);
    if (url.isEmpty) return null;
    return {
      'book_source_url': url,
      'book_source_name': stringOf(row, const ['book_source_name']),
      'book_source_group': stringOf(row, const ['book_source_group']),
      'book_source_type': intOf(row, const ['book_source_type']),
      'enabled': stringOf(row, const ['enabled']).isEmpty
          ? 1
          : (intOf(row, const ['enabled']) == 0 ? 0 : 1),
      'custom_order': intOf(row, const ['custom_order']),
      'weight': intOf(row, const ['weight']),
      'search_url': stringOf(row, const ['search_url']),
      'explore_url': stringOf(row, const ['explore_url']),
      'header': stringOf(row, const ['header']),
      'raw_json': stringOf(row, const ['raw_json']),
      'last_update_time': intOf(row, const ['last_update_time']),
      'respond_time': intOf(row, const ['respond_time']),
      'last_check_time': intOf(row, const ['last_check_time']),
    };
  }

  static Map<String, Object?>? bookmark(Map<String, Object?> row) {
    final id = stringOf(row, const ['id', 'bookmark_id']);
    final bookId = stringOf(row, const ['book_id', 'bookId']);
    if (id.isEmpty || bookId.isEmpty) return null;
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': intOf(row, const [
        'chapter_index',
        'chapterIndex',
        'cur',
      ]),
      'page_index': intOf(row, const ['page_index', 'pageIndex', 'idx']),
      'chapter_name': stringOf(row, const [
        'chapter_name',
        'chapterName',
        'name',
      ]),
      'excerpt': stringOf(row, const ['excerpt', 'text', 'content']),
      'created_at': intOf(row, const [
        'created_at',
        'createdAt',
        'createTime',
        'time',
      ]),
    };
  }

  static Map<String, Object?>? readingHistory(Map<String, Object?> row) {
    final bookId = stringOf(row, const ['book_id', 'bookId']);
    if (bookId.isEmpty) return null;
    return {
      'book_id': bookId,
      'chapter_index': intOf(row, const [
        'chapter_index',
        'chapterIndex',
        'cur',
      ]),
      'page_index': intOf(row, const ['page_index', 'pageIndex', 'idx']),
      'chapter_name': stringOf(row, const [
        'chapter_name',
        'chapterName',
        'name',
      ]),
      'read_at': intOf(row, const ['read_at', 'readAt', 'time', 'updated_at']),
    };
  }

  static String stringOf(Map<String, Object?> row, List<String> keys) {
    final value = _first(row, keys);
    if (value == null) return '';
    return value.toString();
  }

  static int intOf(Map<String, Object?> row, List<String> keys) {
    final value = _first(row, keys);
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double doubleOf(Map<String, Object?> row, List<String> keys) {
    final value = _first(row, keys);
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Object? _first(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      return value;
    }
    return null;
  }
}
