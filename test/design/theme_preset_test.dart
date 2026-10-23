import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/design/theme/theme_presets.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  test('has twelve two-colour themes', () {
    expect(LanghuanThemes.all, hasLength(12));
    expect(LanghuanThemes.defaultIndex, inInclusiveRange(0, 11));
  });

  test('theme uses the visible accent and a readable ink', () {
    final light = buildLanghuanTheme(
      dark: false,
      accent: const Color(0xFFFFFF00),
    );
    // A vivid accent stays as the fill colour…
    expect(light.colorScheme.primary, const Color(0xFFFFFF00));
    expect(light.colorScheme.onPrimary, AppColors.black);
    // …while text and icons use a readable tone of the same hue.
    final lightInk = AppColors.readableAccent(
      light.colorScheme.primary,
      Brightness.light,
    );
    expect(_contrast(lightInk, Colors.white), greaterThan(4.4));

    // A near-page accent (dark burgundy on a dark page) falls back to the
    // companion so buttons and progress indicators stay visible.
    final dark = buildLanghuanTheme(
      dark: true,
      accent: const Color(0xFF470125),
    );
    final darkFill = AppColors.themeAccentFor(
      const Color(0xFF470125),
      AppColors.gold,
      Brightness.dark,
    );
    expect(dark.colorScheme.primary, darkFill);
    expect(dark.colorScheme.onPrimary, AppColors.onColorOf(darkFill));
    final darkInk = AppColors.readableAccent(darkFill, Brightness.dark);
    expect(_contrast(darkInk, Colors.black), greaterThan(4.4));
  });

  test('every preset keeps a readable accent on both pages', () {
    for (final preset in LanghuanThemes.all) {
      for (final dark in [false, true]) {
        final brightness = dark ? Brightness.dark : Brightness.light;
        final page = dark ? AppColors.scaffoldDark : AppColors.scaffold;
        final reason = '${preset.name} ${dark ? 'dark' : 'light'}';
        final accent = AppColors.themeAccentFor(
          preset.accent,
          preset.secondary,
          brightness,
        );
        final ink = AppColors.readableAccent(accent, brightness);
        expect(_contrast(ink, page), greaterThan(4.4), reason: reason);

        final large = AppColors.readableAccent(
          accent,
          brightness,
          minRatio: 3,
        );
        expect(_contrast(large, page), greaterThan(2.9), reason: reason);

        final companion = AppColors.companionFor(
          preset.accent,
          preset.secondary,
          brightness,
        );
        expect(_contrast(companion, page), greaterThan(1.55), reason: reason);
      }
    }
  });
}
