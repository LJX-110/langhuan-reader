import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// 3D 书架用到的主题色。
///
/// 渲染对象拿不到 BuildContext，所以在组件里解析一次、随渲染对象一起更新。
/// 所有颜色都从 [AppColors] 与当前主题派生，12 套双色主题与黑白底都直接可用。
@immutable
class ShelfPalette {
  const ShelfPalette({
    required this.paper,
    required this.paperDeep,
    required this.line,
    required this.ink,
    required this.accent,
    required this.companion,
    required this.onAccent,
    required this.dark,
  });

  /// 书页与封面面板底色（白底用暖纸，黑底用深灰）。
  final Color paper;

  /// 纸的另一面：顶面渐变从它收向 [paper]，所以顶面总比页面亮一档暗一档。
  final Color paperDeep;

  /// 细边线（顶面轮廓、面板描边）。
  final Color line;

  /// 地面投影与次要文字。
  final Color ink;

  /// 书脊底色（当前主题可见的强调色）。
  final Color accent;

  /// 辅助点缀（插入标记、选中标记）。
  final Color companion;

  /// 书脊上的文字色，按对比度取黑或白。
  final Color onAccent;

  final bool dark;

  /// 次要文字（作者、进度、格位计数）。
  Color get muted => dark ? AppColors.textMutedDark : AppColors.inkMute;

  static ShelfPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentOf(context);
    return ShelfPalette(
      paper: dark ? AppColors.surfaceDark : AppColors.paperWhite,
      paperDeep: dark
          // 黑底上顶面要亮一档，否则整排书只剩一片书脊。
          ? Color.alphaBlend(
              Colors.white.withValues(alpha: .07),
              AppColors.surfaceDark,
            )
          : AppColors.paperCream,
      line: dark ? AppColors.dividerDark : AppColors.line,
      ink: dark ? AppColors.textOnDark : AppColors.ink,
      accent: accent,
      companion: AppColors.companionOf(context),
      onAccent: AppColors.onColorOf(accent),
      dark: dark,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShelfPalette &&
      other.paper == paper &&
      other.paperDeep == paperDeep &&
      other.line == line &&
      other.ink == ink &&
      other.accent == accent &&
      other.companion == companion &&
      other.onAccent == onAccent &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(
    paper,
    paperDeep,
    line,
    ink,
    accent,
    companion,
    onAccent,
    dark,
  );
}
