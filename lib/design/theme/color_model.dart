import 'dart:io';

import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/settings/font_catalog.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/cache/custom_cache_manager.dart';
import 'package:langhuan/design/theme/theme_presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

class ColorModel with ChangeNotifier {
  BuildContext? buildContext;
  bool dark = false;
  Map _fonts = {};

  int themeIndex = SpUtil.getInt(
    PrefsKeys.themeIndex,
    defValue: LanghuanThemes.defaultIndex,
  ).clamp(0, LanghuanThemes.all.length - 1).toInt();

  LanghuanThemePreset get themePreset => LanghuanThemes.all[themeIndex];

  /// Families already registered with [FontLoader] this process.
  final Set<String> _loadedFamilies = {'Roboto', ''};

  Map fonts() {
    FontCatalog.ensureSeeded();
    if (_fonts.isEmpty) {
      _fonts.addAll(FontCatalog.all());
    }
    return _fonts;
  }

  void reloadFontMap() {
    _fonts = {};
    fonts();
    notifyListeners();
  }

  ThemeData? _theme;
  String font = SpUtil.getString(ReadSetting.fontNameKey, defValue: "Roboto");

  ThemeData get theme {
    if (SpUtil.haveKey("dark")) {
      dark = SpUtil.getBool(PrefsKeys.dark);
    }
    font = ReadSetting.getFontFamily();
    final family = font == "Roboto" || font.isEmpty ? null : font;
    final preset = themePreset;
    _theme = buildLanghuanTheme(
      dark: dark,
      fontFamily: family,
      accent: preset.accent,
      secondaryColor: preset.secondary,
    );
    return _theme!;
  }

  void selectTheme(int index) {
    final next = index.clamp(0, LanghuanThemes.all.length - 1).toInt();
    if (next == themeIndex) return;
    themeIndex = next;
    SpUtil.putInt(PrefsKeys.themeIndex, next);
    notifyListeners();
  }

  void switchModel() {
    dark = !dark;
    SpUtil.putBool(PrefsKeys.dark, dark);
    notifyListeners();
  }

  /// Apply font: register with Flutter, resolve path for Rust, persist.
  /// Returns false if a custom face could not be loaded (caller may toast).
  Future<bool> setFontFamily(String name) async {
    final n = name.isEmpty ? 'Roboto' : name;
    final ok = await ensureFontLoaded(n);
    if (!ok) return false;
    font = n;
    ReadSetting.setFontFamily(n);
    if (n == 'Roboto') {
      // System face — clear SpUtil path so Rust/Dart don't keep the previous TTF.
      ReadSetting.clearFontPath();
    } else {
      final path = await FontCatalog.resolvePath(n);
      // Bundled default may already be ready via pubspec with path filled later.
      ReadSetting.setFontPath(path);
    }
    notifyListeners();
    return true;
  }

  bool isFontLoaded(String fontName) =>
      fontName.isEmpty ||
      fontName == 'Roboto' ||
      fontName == ReadSetting.defaultFontFamily ||
      _loadedFamilies.contains(fontName);

  /// Ensure [fontName] is registered with Flutter's [FontLoader].
  Future<bool> ensureFontLoaded(String fontName) async {
    if (fontName.isEmpty || fontName == 'Roboto') return true;
    // pubspec.yaml already registers the bundled family — no FontLoader needed.
    if (fontName == ReadSetting.defaultFontFamily) {
      _loadedFamilies.add(fontName);
      // Still prefer an extracted path for Rust.
      if (ReadSetting.bundledFontPath.isEmpty) {
        // Bootstrap may not have finished; resolvePath handles empty.
      }
      return true;
    }
    if (_loadedFamilies.contains(fontName)) return true;

    var path = await FontCatalog.resolvePath(fontName);
    if (path.isEmpty) {
      try {
        final info =
            await CustomCacheManager.instanceFont.getFileFromCache(fontName);
        if (info != null) path = info.file.path;
      } catch (_) {}
    }
    if (path.isEmpty || !await File(path).exists()) return false;

    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return false;
      // Prefer sublistView so offset/length of the Uint8List are respected.
      final data = ByteData.sublistView(bytes);
      final loader = FontLoader(fontName);
      loader.addFont(Future.value(data));
      await loader.load();
      _loadedFamilies.add(fontName);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cold-start: load current reader font if custom.
  Future<void> ensureCurrentFontLoaded() async {
    final name = ReadSetting.getFontFamily();
    await ensureFontLoaded(name);
    if (ReadSetting.getFontPath().isEmpty && name != 'Roboto' && name.isNotEmpty) {
      final path = await FontCatalog.resolvePath(name);
      if (path.isNotEmpty) ReadSetting.setFontPath(path);
    }
    // Theme/body may have painted with fallback before FontLoader finished.
    if (name != 'Roboto' && name.isNotEmpty) {
      notifyListeners();
    }
  }
}
