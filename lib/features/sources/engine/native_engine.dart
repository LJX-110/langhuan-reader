import 'dart:convert';

import 'package:flutter/services.dart';

/// 原生引擎（阅读裁剪集）MethodChannel 封装。
///
/// 通道：`langhuan/engine`（Android 侧见 `EngineBridge.kt`）。
/// 全部返回 facade 的 JSON 文本并在此解析为 Map；失败返回 null（调用方决定降级）。
/// 是否启用由调用方按用户开关决定（默认关闭）。
class NativeEngine {
  NativeEngine._();

  static const MethodChannel _channel = MethodChannel('langhuan/engine');

  /// 探测通道是否可用（未接线/旧包返回 false）。
  static Future<bool> ping() async {
    try {
      final ok = await _channel.invokeMethod<bool>('ping');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// 搜索：`{ok, hits:[{name,author,coverUrl,bookUrl,lastChapter,intro,kind}], error}`。
  static Future<Map<String, dynamic>?> search(
    String sourceJson,
    String keyword,
  ) =>
      _call('search', {'source': sourceJson, 'keyword': keyword});

  /// 详情：`{ok, book}`（book 为实体 JSON 文本）。
  static Future<Map<String, dynamic>?> bookInfo(
    String sourceJson,
    String bookJson,
  ) =>
      _call('bookInfo', {'source': sourceJson, 'book': bookJson});

  /// 目录：`{ok, book, chapters}`。
  static Future<Map<String, dynamic>?> toc(
    String sourceJson,
    String bookJson,
  ) =>
      _call('toc', {'source': sourceJson, 'book': bookJson});

  /// 正文：`{ok, content}`。
  static Future<Map<String, dynamic>?> content(
    String sourceJson,
    String bookJson,
    String chapterJson,
    String nextChapterUrl,
  ) =>
      _call('content', {
        'source': sourceJson,
        'book': bookJson,
        'chapter': chapterJson,
        'nextChapterUrl': nextChapterUrl,
      });

  static Future<Map<String, dynamic>?> _call(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final raw = await _channel.invokeMethod<String>(method, args);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
