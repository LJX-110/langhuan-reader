import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/features/reader/pagination/book_pager.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/entities/text_page.dart';

/// 分页唯一实现：Rust `book_pager`。
///
/// 2026-11-06 起删除 Dart 运行时兜底；Rust 不可用/结果异常时抛出
/// [StateError]，由上层展示错误页 + 重试。Dart 不再参与生产分页。
class TextComposition {
  TextComposition._();

  /// Collect layout metrics on the UI isolate (SpUtil / Screen are main-only).
  static Map<String, dynamic> layoutParams({bool shouldJustifyHeight = false}) {
    final fontSize = ReadSetting.getFontSize();
    final lineHeight = ReadSetting.getLineHeight();
    final topPad = ReadSetting.contentTopInset();
    final bottomPad = ReadSetting.contentBottomInset();
    final rawH = Screen.height - topPad - bottomPad;
    final boxH = rawH > 120 ? rawH : (Screen.height * 0.7).clamp(200.0, 2000.0);
    final boxW = Screen.width > 0 ? Screen.width : 360.0;
    return <String, dynamic>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paragraph': ReadSetting.getParagraph() * fontSize * lineHeight,
      'padH': ReadSetting.getPageDis().toDouble(),
      'boxW': boxW,
      'boxH': boxH,
      'topSafe': ReadSetting.chapterTitleBandTop(),
      'bottomSafe': Screen.bottomSafeHeight,
      'fontFamily': ReadSetting.getFontFamily(),
      'fontPath': ReadSetting.getFontPath(),
      'shouldJustifyHeight': shouldJustifyHeight,
      'abi': bookPagerAbiVersion,
      'engineRevision': bookPagerLayoutRevision,
      'textAlign': ReadSetting.getTextAlign(),
    };
  }

  /// Sync parse — may block the current isolate. Prefer [parseContentAsync].
  static List<TextPage> parseContent(
    ReadPage readPage, {
    bool shouldJustifyHeight = true,
  }) {
    final p = layoutParams(shouldJustifyHeight: shouldJustifyHeight);
    return _parseWithParams(readPage, p);
  }

  /// Async parse on the caller isolate; Rust FFI is not isolate-safe here.
  static Future<List<TextPage>> parseContentAsync(
    ReadPage readPage, {
    bool shouldJustifyHeight = true,
  }) async {
    final p = layoutParams(shouldJustifyHeight: shouldJustifyHeight);
    final fontPath = p['fontPath'] as String? ?? '';
    if (!BookPager.isAvailable) {
      throw StateError('Rust 分页库不可用：${BookPager.lastError ?? "unknown"}');
    }
    if (fontPath.isEmpty) {
      throw StateError('Rust 分页缺少字体路径');
    }

    final pages = await BookPager.paginateAsync(
      text: readPage.chapterContent,
      fontSize: p['fontSize'] as double,
      lineHeight: p['lineHeight'] as double,
      paragraph: p['paragraph'] as double,
      boxWidth: p['boxW'] as double,
      boxHeight: p['boxH'] as double,
      paddingHorizontal: p['padH'] as double,
      paddingVertical: 0,
      shouldJustifyHeight: shouldJustifyHeight,
      fontPath: fontPath,
      fontFamily: p['fontFamily'] as String,
      textAlign: p['textAlign'] as String,
    );
    final totalLines = pages.fold<int>(0, (n, page) => n + page.lines.length);
    if (_looksBrokenPagination(
      pages,
      readPage.chapterContent,
      p['boxW'] as double,
      p['fontSize'] as double,
    )) {
      AppLog.w(
        'Pager',
        'Rust broken pagination pages=${pages.length} lines=$totalLines',
      );
      throw StateError('Rust 分页结果异常（整章单行）');
    }
    AppLog.i(
      'Pager',
      'ENGINE=RUST pages=${pages.length} totalLines=$totalLines',
    );
    return pages;
  }

  static List<TextPage> _parseWithParams(
    ReadPage readPage,
    Map<String, dynamic> p,
  ) {
    final fontPath = p['fontPath'] as String? ?? '';
    if (!BookPager.isAvailable) {
      throw StateError('Rust 分页库不可用：${BookPager.lastError ?? "unknown"}');
    }
    if (fontPath.isEmpty) {
      throw StateError('Rust 分页缺少字体路径');
    }
    return BookPager.paginate(
      text: readPage.chapterContent,
      fontSize: p['fontSize'] as double,
      lineHeight: p['lineHeight'] as double,
      paragraph: p['paragraph'] as double,
      boxWidth: p['boxW'] as double,
      boxHeight: p['boxH'] as double,
      paddingHorizontal: p['padH'] as double,
      paddingVertical: 0,
      shouldJustifyHeight: p['shouldJustifyHeight'] as bool? ?? true,
      fontPath: fontPath,
      fontFamily: p['fontFamily'] as String,
      textAlign: p['textAlign'] as String,
    );
  }

  /// Detect "whole chapter as one TextLine" failure mode from native pager.
  static bool _looksBrokenPagination(
    List<TextPage> pages,
    String content,
    double boxW,
    double fontSize,
  ) {
    if (content.trim().length < 40) return false;
    if (pages.isEmpty) return true;
    final totalLines = pages.fold<int>(0, (n, p) => n + p.lines.length);
    if (totalLines == 0) return true;
    if (totalLines == 1 && content.trim().length > 60) return true;
    final maxChars = (boxW / (fontSize * 0.85)).floor().clamp(8, 200);
    for (final p in pages) {
      for (final line in p.lines) {
        if (line.text.runes.length > maxChars * 2) return true;
      }
    }
    return false;
  }
}
