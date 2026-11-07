import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// 备份格式标识与版本；只在 v1 上做兼容解析。
const String backupFormat = 'langhuan-backup';
const int backupVersion = 1;

/// 单次导入的硬上限：防止畸形文件把 UI/数据库拖死。
const int _maxBytes = 8 * 1024 * 1024;
const int _maxBooks = 5000;
const int _maxBookmarks = 20000;
const int _maxHistory = 5000;
const int _maxSources = 500;
const int _maxTags = 1000;
const int _maxBookTags = 20000;
const int _maxReplaceRules = 500;

/// 备份里允许出现的设置键；不包含 Token、仓库地址、字体文件路径等敏感项。
const Set<String> backupSettingKeys = {
  'theme_index',
  'shelf_view',
  'turnPageAnima',
  'reader_text_align',
  'reader_focus_mode',
  'reader_font_weight',
  'reader_chinese_mode',
  'READINGSTYLE',
  'download_wifi_only',
  'leftClickNext',
};

// 列白名单与 `ReaderDatabase` schema 对齐；新增列时同步这里并升备份版本。
const List<String> _bookColumns = [
  'id',
  'name',
  'author',
  'cover_url',
  'category',
  'description',
  'source_url',
  'book_url',
  'origin_name',
  'toc_url',
  'chapter_index',
  'page_index',
  'scroll_offset',
  'reading_chapter',
  'latest_chapter',
  'sort_time',
  'has_update',
  'updated_at',
  'on_shelf',
  'anchor_offset',
];

const List<String> _bookmarkColumns = [
  'id',
  'book_id',
  'chapter_index',
  'page_index',
  'chapter_name',
  'excerpt',
  'created_at',
];

const List<String> _historyColumns = [
  'book_id',
  'chapter_index',
  'page_index',
  'chapter_name',
  'read_at',
];

const List<String> _tagColumns = ['id', 'name', 'created_at'];

const List<String> _bookTagColumns = ['book_id', 'tag_id'];

const List<String> _replaceRuleColumns = [
  'id',
  'name',
  'pattern',
  'replacement',
  'is_regex',
  'scope_content',
  'scope_title',
  'enabled',
  'order_index',
];

const List<String> _sourceColumns = [
  'book_source_url',
  'book_source_name',
  'book_source_group',
  'book_source_type',
  'enabled',
  'custom_order',
  'weight',
  'search_url',
  'explore_url',
  'header',
  'raw_json',
  'last_update_time',
  'respond_time',
  'last_check_time',
];

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 解析后的备份预览（导入前给用户确认）。
class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.books,
    required this.bookmarks,
    required this.history,
    required this.tags,
    required this.replaceRules,
    required this.sources,
    required this.settings,
    required this.includeSources,
  });

  final int createdAt;
  final String appVersion;
  final int books;
  final int bookmarks;
  final int history;
  final int tags;
  final int replaceRules;
  final int sources;
  final int settings;
  final bool includeSources;
}

class BackupApplyResult {
  const BackupApplyResult({
    required this.insertedBooks,
    required this.keptBooks,
    required this.bookmarks,
    required this.history,
    required this.tags,
    required this.replaceRules,
    required this.sources,
    required this.settings,
  });

  final int insertedBooks;
  final int keptBooks;
  final int bookmarks;
  final int history;
  final int tags;
  final int replaceRules;
  final int sources;
  final int settings;

  String get summary =>
      '已恢复 $insertedBooks 本'
      '${keptBooks > 0 ? '（$keptBooks 本保留本地进度）' : ''}、'
      '$bookmarks 个书签、$history 条阅读记录'
      '${tags > 0 ? '、$tags 个标签' : ''}'
      '${replaceRules > 0 ? '、$replaceRules 条替换规则' : ''}'
      '${sources > 0 ? '、$sources 个书源' : ''}'
      '${settings > 0 ? '、$settings 项设置' : ''}';
}

/// 本机数据备份与恢复。
///
/// v1 语义：只备份元数据/进度/书签/阅读记录/标签/替换规则
/// （可选书源与白名单设置），不含章节正文、分页缓存、Cookie、Token、字体文件。
/// 恢复为合并写入：本地已有的书与进度不覆盖；书签按 id 更新；
/// 阅读记录取更晚的一条；书源与替换规则只补缺失项。
class BackupService {
  BackupService({ReaderDatabase? db, Future<SharedPreferences>? prefs})
    : _db = db ?? ReaderDatabase.instance,
      _prefs = prefs ?? SharedPreferences.getInstance();

  final ReaderDatabase _db;
  final Future<SharedPreferences> _prefs;

  static final BackupService instance = BackupService();

  Future<Database> get _database => _db.database;

  /// 生成 gzip JSON 字节。
  Future<Uint8List> exportBytes({bool includeSources = false}) async {
    final db = await _database;
    final prefs = await _prefs;
    String version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // 桌面/测试环境没有 PackageInfo 插件时的兜底；不影响备份内容。
    }
    final books = await db.query('books', columns: _bookColumns);
    final bookmarks = await db.query('bookmarks', columns: _bookmarkColumns);
    final history = await db.query('reading_history', columns: _historyColumns);
    final tags = await db.query('tags', columns: _tagColumns);
    final bookTags = await db.query('book_tags', columns: _bookTagColumns);
    final replaceRules = await db.query(
      'replace_rules',
      columns: _replaceRuleColumns,
    );
    final sources = includeSources
        ? await db.query('sources', columns: _sourceColumns)
        : const <Map<String, Object?>>[];
    final settings = <String, Object?>{};
    for (final key in backupSettingKeys) {
      final value = prefs.get(key);
      if (value is bool || value is int || value is double || value is String) {
        settings[key] = value;
      } else if (value is List<String>) {
        settings[key] = value;
      }
    }

    final payload = <String, Object?>{
      'format': backupFormat,
      'version': backupVersion,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'appVersion': version,
      'books': books,
      'bookmarks': bookmarks,
      'history': history,
      'tags': tags,
      'bookTags': bookTags,
      'replaceRules': replaceRules,
      'includeSources': includeSources,
      if (includeSources) 'sources': sources,
      'settings': settings,
    };
    final text = jsonEncode(payload);
    if (utf8.encode(text).length > _maxBytes) {
      throw const BackupFormatException('数据超过 8 MiB，请减少书源或书签后重试');
    }
    return Uint8List.fromList(gzip.encode(utf8.encode(text)));
  }

  /// 解析并校验备份；失败抛 [BackupFormatException]（中文可行动文案）。
  Future<BackupPreview> preview(Uint8List bytes) async {
    try {
      return await _parse(await compute(_decodeBytes, bytes));
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('备份文件无法解析');
    }
  }

  /// 合并导入；单事务，失败整体回滚。
  Future<BackupApplyResult> apply(Uint8List bytes) async {
    Map<String, Object?> bundle;
    try {
      bundle = await compute(_decodeBytes, bytes);
      await _parse(bundle);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('备份文件无法解析');
    }
    final db = await _database;
    final prefs = await _prefs;

    var insertedBooks = 0;
    var keptBooks = 0;
    var bookmarkCount = 0;
    var historyCount = 0;
    var tagCount = 0;
    var replaceRuleCount = 0;
    var sourceCount = 0;
    var settingCount = 0;
    final bookIds = <String>{};
    final tagIds = <String>{};

    await db.transaction((txn) async {
      for (final row in _rows(bundle, 'books')) {
        final id = _str(row['id']);
        if (id.isEmpty) continue;
        final existing = await txn.query(
          'books',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          keptBooks++;
          bookIds.add(id);
          continue;
        }
        await txn.insert('books', row);
        insertedBooks++;
        bookIds.add(id);
      }

      for (final row in _rows(bundle, 'bookmarks')) {
        if (!bookIds.contains(_str(row['book_id']))) continue;
        final existing = await txn.query(
          'bookmarks',
          columns: ['created_at'],
          where: 'id = ?',
          whereArgs: [_str(row['id'])],
          limit: 1,
        );
        // 同一书签以较新的一份为准，避免恢复旧备份冲掉本地新摘录。
        if (existing.isNotEmpty &&
            _int(row['created_at']) <= _int(existing.first['created_at'])) {
          continue;
        }
        await txn.insert(
          'bookmarks',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        bookmarkCount++;
      }

      for (final row in _rows(bundle, 'history')) {
        final bookId = _str(row['book_id']);
        if (!bookIds.contains(bookId)) continue;
        final existing = await txn.query(
          'reading_history',
          columns: ['read_at'],
          where: 'book_id = ?',
          whereArgs: [bookId],
          limit: 1,
        );
        final localReadAt = existing.isEmpty
            ? -1
            : _int(existing.first['read_at']);
        if (_int(row['read_at']) <= localReadAt) continue;
        await txn.insert(
          'reading_history',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        historyCount++;
      }

      for (final row in _rows(bundle, 'tags')) {
        final id = _str(row['id']);
        if (id.isEmpty) continue;
        final inserted = await txn.insert(
          'tags',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted != 0) tagCount++;
        tagIds.add(id);
      }
      // 本地已有标签也允许挂接备份里的书签（合并导入不重建用户已有标签）。
      final localTags = await txn.query('tags', columns: ['id']);
      for (final row in localTags) {
        final id = _str(row['id']);
        if (id.isNotEmpty) tagIds.add(id);
      }
      for (final row in _rows(bundle, 'bookTags')) {
        final bookId = _str(row['book_id']);
        final tagId = _str(row['tag_id']);
        if (!bookIds.contains(bookId) || !tagIds.contains(tagId)) continue;
        await txn.insert(
          'book_tags',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final row in _rows(bundle, 'replaceRules')) {
        final inserted = await txn.insert(
          'replace_rules',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted != 0) replaceRuleCount++;
      }

      for (final row in _rows(bundle, 'sources')) {
        final rowId = await txn.insert(
          'sources',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rowId != 0) sourceCount++;
      }
    });

    // 设置只补缺失项：本地已有的偏好不覆盖。
    final settings = bundle['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        final key = entry.key.toString();
        if (!backupSettingKeys.contains(key)) continue;
        if (prefs.containsKey(key)) continue;
        final value = entry.value;
        final ok = switch (value) {
          bool v => await prefs.setBool(key, v),
          int v => await prefs.setInt(key, v),
          double v => await prefs.setDouble(key, v),
          String v => await prefs.setString(key, v),
          List v when v.every((e) => e is String) => await prefs.setStringList(
            key,
            v.cast<String>(),
          ),
          _ => false,
        };
        if (ok) settingCount++;
      }
    }

    return BackupApplyResult(
      insertedBooks: insertedBooks,
      keptBooks: keptBooks,
      bookmarks: bookmarkCount,
      history: historyCount,
      tags: tagCount,
      replaceRules: replaceRuleCount,
      sources: sourceCount,
      settings: settingCount,
    );
  }

  Future<BackupPreview> _parse(Map<String, Object?> bundle) async {
    if (bundle['format'] != backupFormat ||
        bundle['version'] != backupVersion) {
      throw const BackupFormatException('不是受支持的琅嬛阁备份文件');
    }
    final createdAt = _int(bundle['createdAt']);
    if (createdAt <= 0) {
      throw const BackupFormatException('备份时间缺失或无效');
    }
    final books = _rows(bundle, 'books', limit: _maxBooks);
    final bookmarks = _rows(bundle, 'bookmarks', limit: _maxBookmarks);
    final history = _rows(bundle, 'history', limit: _maxHistory);
    final tags = _rows(bundle, 'tags', limit: _maxTags);
    _rows(bundle, 'bookTags', limit: _maxBookTags);
    final replaceRules = _rows(bundle, 'replaceRules', limit: _maxReplaceRules);
    final sources = _rows(bundle, 'sources', limit: _maxSources);
    final settings = bundle['settings'];
    final settingCount = settings is Map
        ? settings.entries
              .where((e) => backupSettingKeys.contains(e.key.toString()))
              .length
        : 0;

    for (final row in books) {
      if (_str(row['id']).isEmpty) {
        throw const BackupFormatException('备份含缺少 id 的书籍');
      }
    }
    for (final row in bookmarks) {
      if (_str(row['id']).isEmpty || _str(row['book_id']).isEmpty) {
        throw const BackupFormatException('备份含缺少标识的书签');
      }
    }
    for (final row in history) {
      if (_str(row['book_id']).isEmpty) {
        throw const BackupFormatException('备份含缺少书籍标识的阅读记录');
      }
    }
    for (final row in tags) {
      if (_str(row['id']).isEmpty) {
        throw const BackupFormatException('备份含缺少标识的标签');
      }
    }
    for (final row in replaceRules) {
      if (_str(row['id']).isEmpty) {
        throw const BackupFormatException('备份含缺少标识的替换规则');
      }
    }

    return BackupPreview(
      createdAt: createdAt,
      appVersion: _str(bundle['appVersion']),
      books: books.length,
      bookmarks: bookmarks.length,
      history: history.length,
      tags: tags.length,
      replaceRules: replaceRules.length,
      sources: sources.length,
      settings: settingCount,
      includeSources: bundle['includeSources'] == true,
    );
  }

  /// 从解析结果取某类行；字段只保留白名单列并统一类型。
  static List<Map<String, Object?>> _rows(
    Map<String, Object?> bundle,
    String table, {
    int? limit,
  }) {
    final raw = bundle[table];
    if (raw is! List) return const [];
    if (limit != null && raw.length > limit) {
      throw BackupFormatException('备份 $table 数量超过上限');
    }
    final columns = switch (table) {
      'books' => _bookColumns,
      'bookmarks' => _bookmarkColumns,
      'history' => _historyColumns,
      'tags' => _tagColumns,
      'bookTags' => _bookTagColumns,
      'replaceRules' => _replaceRuleColumns,
      'sources' => _sourceColumns,
      _ => const <String>[],
    };
    if (columns.isEmpty) return const [];
    return raw
        .whereType<Map>()
        .map((row) => _sanitize(Map<String, Object?>.from(row), columns))
        .toList(growable: false);
  }

  static Map<String, Object?> _sanitize(
    Map<String, Object?> row,
    List<String> columns,
  ) {
    final out = <String, Object?>{};
    for (final col in columns) {
      final value = row[col];
      if (value == null) continue;
      if (value is num || value is String) out[col] = value;
    }
    // 统一数值列，避免备份文件把字符串塞进 INTEGER 列。
    for (final col in const [
      'chapter_index',
      'page_index',
      'sort_time',
      'has_update',
      'on_shelf',
      'anchor_offset',
      'created_at',
      'read_at',
      'book_source_type',
      'enabled',
      'custom_order',
      'weight',
      'last_update_time',
      'respond_time',
      'last_check_time',
      'is_regex',
      'scope_content',
      'scope_title',
      'order_index',
    ]) {
      if (!out.containsKey(col)) continue;
      out[col] = _int(out[col]);
    }
    if (out.containsKey('scroll_offset')) {
      out['scroll_offset'] = _double(out['scroll_offset']);
    }
    return out;
  }

  static String _str(Object? value) => value is String ? value : '';
  static int _int(Object? value) => value is int
      ? value
      : (value is num ? value.toInt() : int.tryParse('$value') ?? 0);
  static double _double(Object? value) => value is double
      ? value
      : (value is num ? value.toDouble() : double.tryParse('$value') ?? 0);
}

/// 顶层函数，供 `compute` 在后台 isolate 解码 gzip JSON。
Map<String, Object?> _decodeBytes(Uint8List bytes) {
  if (bytes.length > _maxBytes) {
    throw const BackupFormatException('备份文件超过 8 MiB');
  }
  Uint8List raw;
  try {
    raw = Uint8List.fromList(gzip.decode(bytes));
  } catch (_) {
    raw = bytes;
  }
  if (raw.length > _maxBytes) {
    throw const BackupFormatException('备份内容超过 8 MiB');
  }
  final decoded = jsonDecode(utf8.decode(raw));
  if (decoded is! Map) {
    throw const BackupFormatException('备份内容不是 JSON 对象');
  }
  return Map<String, Object?>.from(decoded);
}
