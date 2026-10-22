import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Colours shared by the reader top bar and bottom panels. They follow the
/// reader paper instead of the app theme so chrome never clashes with the page
/// underneath.
class ReaderChrome {
  const ReaderChrome(this.paper);

  final PaperTheme paper;

  Color get panelBg => ReadSetting.paperColor(paper);

  Color get fg => ReadSetting.inkColor(paper);

  Color get muted => ReadSetting.metaColor(paper);

  Color get divider => paper == PaperTheme.night
      ? const Color(0x33FFFFFF)
      : fg.withValues(alpha: 0.12);

  /// Subtle lift over paper for chips / outline buttons.
  Color get chipBg => paper == PaperTheme.night
      ? const Color(0xFF1C1C1C)
      : Color.alphaBlend(fg.withValues(alpha: 0.06), panelBg);
}

SliderThemeData readerSliderTheme(BuildContext context, ReaderChrome chrome) {
  final accent = AppColors.accentOf(context);
  return SliderTheme.of(context).copyWith(
    trackHeight: 3,
    activeTrackColor: accent,
    inactiveTrackColor: chrome.divider,
    thumbColor: accent,
    overlayColor: AppColors.accentSoftOf(context, alpha: 0.12),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  );
}
