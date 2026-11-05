import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/features/sources/engine/native_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';

/// 原生引擎试点桥（E3b）。
///
/// 开关开启且通道可用时，把 详情 / 目录 / 正文 优先交给原生引擎
/// （阅读裁剪集：`engine/facade` ↔ `EngineBridge.kt` ↔ `NativeEngine`）；
/// 任何失败都返回 null，调用方回落 Dart 引擎——默认关闭、行为零变化。
class NativeEngineBridge {
  NativeEngineBridge._();

  static const _tag = 'NativeEngine';

  /// 用户开关（我的 → 其他 → 原生引擎（实验））。
  /// 防御：任何环境异常（如测试中 SpUtil 未初始化）都视为关闭。
  static bool get enabled {
    try {
      return SpUtil.getBool(PrefsKeys.nativeEngineEnabled);
    } catch (_) {
      return false;
    }
  }

  /// 开关 + 通道探活同时通过才走原生；异常一律视为不可用。
  static Future<bool> usable() async {
    try {
      if (!enabled) return false;
      return await NativeEngine.ping();
    } catch (_) {
      return false;
    }
  }

  /// 书源 JSON：直接用入库时保存的 Legado 原文（导入/编辑器都保真）。
  static String? sourceJson(BookSource source) =>
      source.rawJson.trim().isEmpty ? null : source.rawJson;

  /// 构造 Kotlin `Book` 可解码的 JSON（字段名对齐实体序列化名；
  /// 空值给 null，Kotlin 侧全部有默认值）。
  @visibleForTesting
  static Map<String, dynamic> buildBookJson({
    required String bookUrl,
    required String tocUrl,
    required String origin,
    required String originName,
    String name = '',
    String author = '',
    String kind = '',
    String intro = '',
    String coverUrl = '',
    String latestChapterTitle = '',
    String wordCount = '',
    int totalChapterNum = 0,
  }) => {
    'bookUrl': bookUrl,
    'tocUrl': tocUrl,
    'origin': origin,
    'originName': originName,
    'name': name,
    'author': author,
    'kind': kind.isEmpty ? null : kind,
    'intro': intro.isEmpty ? null : intro,
    'coverUrl': coverUrl.isEmpty ? null : coverUrl,
    'latestChapterTitle': latestChapterTitle.isEmpty ? null : latestChapterTitle,
    'wordCount': wordCount.isEmpty ? null : wordCount,
    'totalChapterNum': totalChapterNum,
  };

  /// 解一层 facade 回包；`ok != true` / 结构不对返回 null（并记录原因）。
  @visibleForTesting
  static Map<String, dynamic>? parseStagePayload(
    Map<String, dynamic>? resp,
    String stage,
  ) {
    if (resp == null) return null;
    if (resp['ok'] != true) {
      final err = resp['error'];
      if (err != null) AppLog.w(_tag, '$stage fail: $err');
      return null;
    }
    return resp;
  }

  /// 详情：成功返回 [BookInfo]，失败/未启用返回 null。
  static Future<BookInfo?> bookInfo(
    BookSource source,
    String bookUrl, {
    SearchBook? seed,
  }) async {
    final src = sourceJson(source);
    if (src == null || !await usable()) return null;
    final book = buildBookJson(
      bookUrl: bookUrl,
      tocUrl: '',
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: seed?.name ?? '',
      author: seed?.author ?? '',
      kind: seed?.kind ?? '',
      intro: seed?.intro ?? '',
      coverUrl: seed?.coverUrl ?? '',
      latestChapterTitle: seed?.lastChapter ?? '',
      wordCount: seed?.wordCount ?? '',
    );
    final resp = await NativeEngine.bookInfo(src, jsonEncode(book));
    final parsed = parseStagePayload(resp, 'bookInfo');
    if (parsed == null) return null;
    final rawBook = parsed['book'];
    final map = rawBook is String ? _decodeMap(rawBook) : null;
    if (map == null) return null;
    final resolvedBookUrl = (map['bookUrl'] ?? '').toString();
    AppLog.i(_tag, 'bookInfo ok "${source.bookSourceName}"');
    return BookInfo(
      name: (map['name'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      category: (map['kind'] ?? '').toString(),
      description: (map['intro'] ?? '').toString(),
      latestChapter: (map['latestChapterTitle'] ?? '').toString(),
      sourceUrl: source.bookSourceUrl,
      originName: source.bookSourceName,
      bookUrl: resolvedBookUrl.isEmpty ? bookUrl : resolvedBookUrl,
      tocUrl: (map['tocUrl'] ?? '').toString(),
    );
  }

  /// 目录：成功返回非空章节表，失败/未启用返回 null。
  static Future<List<SourceChapter>?> toc(
    BookSource source,
    String tocUrl, {
    String bookUrl = '',
    String bookName = '',
  }) async {
    final src = sourceJson(source);
    if (src == null || !await usable()) return null;
    final baseBookUrl = bookUrl.isEmpty ? tocUrl : bookUrl;
    final book = buildBookJson(
      bookUrl: baseBookUrl,
      tocUrl: tocUrl,
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: bookName,
    );
    final resp = await NativeEngine.toc(src, jsonEncode(book));
    final parsed = parseStagePayload(resp, 'toc');
    if (parsed == null) return null;
    final rawChapters = parsed['chapters'];
    final list = rawChapters is String ? _decodeList(rawChapters) : null;
    if (list == null) return null;
    final out = <SourceChapter>[];
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m is! Map) continue;
      final isVolume = m['isVolume'] == true;
      final url = (m['url'] ?? '').toString();
      if (url.isEmpty && !isVolume) continue;
      out.add(
        SourceChapter(
          name: (m['title'] ?? '').toString(),
          url: url,
          isVolume: isVolume,
          index: (m['index'] is num) ? (m['index'] as num).toInt() : i,
          info: (m['tag'] ?? '').toString(),
        ),
      );
    }
    if (out.isEmpty) return null;
    AppLog.i(_tag, 'toc ok "${source.bookSourceName}" chapters=${out.length}');
    return out;
  }

  /// 正文：成功返回非空文本，失败/未启用返回 null。
  static Future<String?> content({
    required BookSource source,
    required String chapterUrl,
    String bookUrl = '',
    String bookName = '',
    String chapterTitle = '',
    int chapterIndex = 0,
    String nextChapterUrl = '',
    int totalChapterNum = 0,
  }) async {
    final src = sourceJson(source);
    if (src == null || !await usable()) return null;
    final baseBookUrl = bookUrl.isEmpty ? chapterUrl : bookUrl;
    final book = buildBookJson(
      bookUrl: baseBookUrl,
      tocUrl: '',
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: bookName,
      totalChapterNum: totalChapterNum,
    );
    final chapter = jsonEncode({
      'url': chapterUrl,
      'title': chapterTitle,
      'index': chapterIndex,
      'bookUrl': baseBookUrl,
    });
    final resp = await NativeEngine.content(
      src,
      jsonEncode(book),
      chapter,
      nextChapterUrl,
    );
    final parsed = parseStagePayload(resp, 'content');
    if (parsed == null) return null;
    final text = (parsed['content'] ?? '').toString();
    if (text.isEmpty) return null;
    AppLog.i(_tag, 'content ok len=${text.length}');
    return text;
  }

  static Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  static List<dynamic>? _decodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) return v;
    } catch (_) {}
    return null;
  }
}
