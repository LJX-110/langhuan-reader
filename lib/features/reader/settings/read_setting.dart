import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:flutter/material.dart';

/// Solid paper theme for the reader canvas (WeChat Reading style).
enum PaperTheme { white, cream, green, night }

class ReadSetting {
  /// Legacy texture backgrounds (optional advanced skins).
  static List<String> bgImg = [
    "QR_bg_1.jpg",
    "QR_bg_2.jpg",
    "QR_bg_3.jpg",
    "QR_bg_5.jpg",
    "QR_bg_7.png",
    "QR_bg_8.png",
    "QR_bg_4.jpg",
  ];

  static bool isDark() => SpUtil.getBool(PrefsKeys.dark);
  static String bgsKey = "BGSKEY";
  static String fontSizeKey = "FONT_SIZE";
  static String latterHeight = "LINE_HEIGHT";
  static String latterLead = "LATTER_LEAD";
  static String latterSpace = "LATTER_SPACE";
  static String paragraph = "paragraph";
  static String pageDis = "pageDis";
  static String paperKey = "paper_theme";
  static String useSolidPaperKey = "use_solid_paper";
  static String fontMigratedKey = "font_size_migrated_v19";
  static String fontNameKey = "fontName";
  static String fontPathKey = "fontPath";

  /// Product solid papers (preferred over texture images).
  static const List<PaperTheme> solidPapers = [
    PaperTheme.white,
    PaperTheme.cream,
    PaperTheme.green,
    PaperTheme.night,
  ];

  static String paperLabel(PaperTheme t) {
    switch (t) {
      case PaperTheme.white:
        return '白';
      case PaperTheme.cream:
        return '米';
      case PaperTheme.green:
        return '绿';
      case PaperTheme.night:
        return '夜';
    }
  }

  static Color paperColor(PaperTheme t) {
    switch (t) {
      case PaperTheme.white:
        return AppColors.paperWhite;
      case PaperTheme.cream:
        return AppColors.paperCream;
      case PaperTheme.green:
        return AppColors.paperGreen;
      case PaperTheme.night:
        return AppColors.paperNight;
    }
  }

  static Color inkColor(PaperTheme t) {
    switch (t) {
      case PaperTheme.white:
      case PaperTheme.cream:
        return AppColors.inkOnLight;
      case PaperTheme.green:
        return AppColors.inkOnGreen;
      case PaperTheme.night:
        return AppColors.inkOnNight;
    }
  }

  static Color metaColor(PaperTheme t) {
    switch (t) {
      case PaperTheme.night:
        return const Color(0x66FFFFFF);
      case PaperTheme.green:
        return AppColors.inkOnGreen.withValues(alpha: 0.55);
      default:
        return AppColors.textSecondary;
    }
  }

  static PaperTheme getPaperTheme() {
    final name = SpUtil.getString(paperKey, defValue: 'cream');
    return PaperTheme.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaperTheme.cream,
    );
  }

  static void setPaperTheme(PaperTheme t) {
    SpUtil.putString(paperKey, t.name);
    // Keep global dark flag aligned with night paper.
    if (t == PaperTheme.night) {
      SpUtil.putBool(PrefsKeys.dark, true);
    } else if (SpUtil.getBool(PrefsKeys.dark) && t != PaperTheme.night) {
      // Leaving night paper turns off global dark for reader consistency.
      SpUtil.putBool(PrefsKeys.dark, false);
    }
  }

  /// Prefer solid paper fill over legacy texture images.
  static bool useSolidPaper() =>
      SpUtil.getBool(useSolidPaperKey, defValue: true);

  static void setUseSolidPaper(bool v) => SpUtil.putBool(useSolidPaperKey, v);

  /// One-shot: old default 26 → calm 19.
  static void migrateFontDefaultsIfNeeded() {
    if (SpUtil.getBool(fontMigratedKey, defValue: false)) return;
    final stored = SpUtil.getDouble(fontSizeKey, defValue: 26);
    if (stored == 26) {
      SpUtil.putDouble(fontSizeKey, 19);
    }
    final lh = SpUtil.getDouble(latterHeight, defValue: 1.8);
    if (lh == 1.8) {
      SpUtil.putDouble(latterHeight, 1.7);
    }
    SpUtil.putBool(fontMigratedKey, true);
  }

  static double listPageChapterName = 200;
  static double listPageBottom = Screen.height / 2;
  static String temp_w = "temp_w";
  static String temp_h = "temp_h";
  static Color textLowColor =
      SpUtil.getBool(PrefsKeys.dark) ? Colors.white10 : Colors.grey.shade50;

  static String poet =
      '琅嬛阁是一款自用的网络小说阅读器。书架、阅读进度与书源保存在本机，'
      '不内置、不提供任何书源或公开书源列表。';
  static String lawWarn =
      '''书源由使用者自行提供，仅供个人学习与阅读。请只导入你有权访问和使用的书源，
不要导入或传播侵犯他人版权的内容。

本应用不内置、不提供、不推荐任何书源，也不绕过付费墙或 DRM。
书源内容、搜索与阅读行为由使用者自行负责；因使用第三方书源产生的法律责任与损失，
由使用者自行承担。

本应用不保证第三方书源的可用性、安全性、准确性或合法性。
网络状况、站点变更、书源规则失效等都可能导致内容无法加载。''';

  static double getFontSize() {
    migrateFontDefaultsIfNeeded();
    return SpUtil.getDouble(fontSizeKey, defValue: 19);
  }

  // ---- Font family / path (reader pagination + paint) ----

  /// Bundled CJK face used when the user has not picked a custom font.
  /// Keep in sync with `pubspec.yaml` fonts entry and assets/fonts/*.
  static const String defaultFontFamily = 'HarmonyOSSansSC';
  static const String defaultFontAsset =
      'assets/fonts/HarmonyOS_Sans_SC_Regular.ttf';

  /// Absolute path of the extracted default TTF (filled by bootstrap).
  /// Separate from user-selected [fontPathKey] so switching fonts cannot
  /// permanently hide the bundled face.
  static String _bundledFontPath = '';

  static void setBundledFontPath(String path) {
    _bundledFontPath = path;
  }

  /// Extracted bundled TTF only (may be empty before bootstrap).
  static String get bundledFontPath => _bundledFontPath;

  static String getFontFamily() {
    final name = SpUtil.getString(fontNameKey, defValue: '');
    // Empty / legacy unset → bundled default. Explicit "Roboto" stays Roboto
    // so 设置 → 系统默认 still works.
    if (name.isEmpty) return defaultFontFamily;
    return name;
  }

  static void setFontFamily(String name) {
    SpUtil.putString(
      fontNameKey,
      name.isEmpty ? defaultFontFamily : name,
    );
  }

  /// Path used by Rust book_pager + paint.
  /// 1) User / selected face path in SpUtil when set
  /// 2) Else bundled face when current family is the default
  /// 3) Else empty (Dart/system)
  static String getFontPath() {
    final custom = SpUtil.getString(fontPathKey, defValue: '');
    if (custom.isNotEmpty) return custom;
    final family = getFontFamily();
    if (family == defaultFontFamily || family.isEmpty) {
      return _bundledFontPath;
    }
    return '';
  }

  static void setFontPath(String path) {
    SpUtil.putString(fontPathKey, path);
  }

  /// Clear the selected path (e.g. switching to system Roboto).
  static void clearFontPath() {
    SpUtil.putString(fontPathKey, '');
  }

  /// Page-turn / scroll mode: 0 无动画 / 1 仿真 / 2 覆盖 / 3 滚动.
  /// See [ReaderPageManager] TYPE_* constants.
  static int getPageTurnMode() =>
      SpUtil.getInt(PrefsKeys.pageTurnMode, defValue: 0);

  static void setPageTurnMode(int mode) {
    SpUtil.putInt(PrefsKeys.pageTurnMode, mode.clamp(0, 3));
  }

  static double getLineHeight() {
    migrateFontDefaultsIfNeeded();
    return SpUtil.getDouble(latterHeight, defValue: 1.7);
  }

  static void setLineHeight(double lineHeight) {
    SpUtil.putDouble(latterHeight, lineHeight);
  }

  static void addLineHeight() {
    SpUtil.putDouble(latterHeight, getLineHeight() + .1);
  }

  static void subLineHeight() {
    SpUtil.putDouble(latterHeight, getLineHeight() - .1);
  }

  static void addLatterSpace() {
    SpUtil.putDouble(latterSpace, getLatterSpace() + 1);
  }

  static void subLatterSpace() {
    SpUtil.putDouble(latterSpace, getLatterSpace() - 1);
  }

  static double getLatterSpace() {
    return SpUtil.getDouble(latterSpace, defValue: 3.0);
  }

  static void setLatterSpace(double v) {
    SpUtil.putDouble(latterSpace, v);
  }

  static void addParagraph() {
    SpUtil.putDouble(paragraph, getParagraph() + .1);
  }

  static void subParagraph() {
    SpUtil.putDouble(paragraph, getParagraph() - .1);
  }

  static double getParagraph() {
    return SpUtil.getDouble(paragraph, defValue: .8);
  }

  static void setParagraph(double v) {
    SpUtil.putDouble(paragraph, v);
  }

  static double getLatterLead() {
    return SpUtil.getDouble(latterLead, defValue: 1);
  }

  static void setFontSize(double fontSize) {
    SpUtil.putDouble(fontSizeKey, fontSize);
  }

  static void calcFontSize(double size) {
    setFontSize(getFontSize() + size);
  }

  static void setPageDis(int s) {
    SpUtil.putInt(pageDis, s);
  }

  static int getPageDis() {
    return SpUtil.getInt(pageDis, defValue: 20);
  }

  static void calcPageDis(int s) {
    SpUtil.putInt(pageDis, getPageDis() + s);
  }

  /// Height of the chapter-title chrome band (below the status / safe area).
  /// Must stay in sync with [ReaderPainter.drawContent].
  static const double contentTopChrome = 36;

  /// Height of the time / page-number chrome band (above the bottom safe area).
  static const double contentBottomChrome = 36;

  /// Gap between chrome labels (chapter title / time+page) and body text.
  /// Applied on both ends so body never crowds the header or footer.
  static const double contentChromeGap = 12;

  /// Top of the chapter-title chrome band.
  static double chapterTitleBandTop() {
    return SpUtil.getDouble(PrefsKeys.topSafeHeight);
  }

  /// Top of the time / page-number chrome band.
  static double bottomChromeBandTop() {
    return Screen.height - Screen.bottomSafeHeight - contentBottomChrome;
  }

  /// Top inset of the paginated content box (and paint offset for body lines).
  /// Body sits between chrome bands with [contentChromeGap] breathing room.
  static double contentTopInset() {
    return chapterTitleBandTop() + contentTopChrome + contentChromeGap;
  }

  /// Bottom inset of the paginated content box.
  static double contentBottomInset() {
    return contentBottomChrome + Screen.bottomSafeHeight + contentChromeGap;
  }

  static double getTempH() {
    return SpUtil.getDouble(temp_h, defValue: 0);
  }

  static void setTempH(double h) {
    SpUtil.putDouble(temp_h, h);
  }

  static double getTempW() {
    return SpUtil.getDouble(temp_w, defValue: 0);
  }

  static void setTempW(double w) {
    SpUtil.putDouble(temp_w, w);
  }
}
