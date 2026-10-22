import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Reader paper theme: prefs, paint invalidation.
class ReaderThemeController {
  ReaderThemeController({
    required this.clearPictures,
    required this.markNeedsPaint,
    required this.notify,
  });

  final void Function() clearPictures;
  final void Function() markNeedsPaint;
  final void Function() notify;

  PaperTheme paperTheme = ReadSetting.getPaperTheme();

  /// Refresh [paperTheme] from prefs (call before paint so menu changes apply).
  void syncPaperTheme() {
    paperTheme = ReadSetting.getPaperTheme();
  }

  /// WeChat-style solid paper swatch.
  Future<void> setPaperTheme(PaperTheme theme) async {
    paperTheme = theme;
    ReadSetting.setPaperTheme(theme);
    clearPictures();
    markNeedsPaint();
    notify();
  }
}
