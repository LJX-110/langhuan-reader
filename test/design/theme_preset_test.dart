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

  test('theme keeps the chosen accent and a readable ink', () {
    final light = buildLanghuanTheme(
      dark: false,
      accent: const Color(0xFFFFFF00),
    );
    // Swatches and filled buttons use the raw colour…
    expect(light.colorScheme.primary, const Color(0xFFFFFF00));
    expect(light.colorScheme.onPrimary, AppColors.black);
    // …while text and icons use a readable tone of the same hue.
    final lightInk = AppColors.readableAccent(
      light.colorScheme.primary,
      Brightness.light,
    );
    expect(_contrast(lightInk, Colors.white), greaterThan(4.4));

    final dark = buildLanghuanTheme(
      dark: true,
      accent: const Color(0xFF470125),
    );
    expect(dark.colorScheme.primary, const Color(0xFF470125));
    final darkInk = AppColors.readableAccent(
      dark.colorScheme.primary,
      Brightness.dark,
    );
    expect(_contrast(darkInk, Colors.black), greaterThan(4.4));
  });

  test('every preset keeps a readable accent on both pages', () {
    for (final preset in LanghuanThemes.all) {
      for (final dark in [false, true]) {
        final theme = buildLanghuanTheme(
          dark: dark,
          accent: preset.accent,
          secondaryColor: preset.secondary,
        );
        final page = dark ? AppColors.scaffoldDark : AppColors.scaffold;
        final ink = AppColors.readableAccent(
          theme.colorScheme.primary,
          theme.brightness,
        );
        expect(
          _contrast(ink, page),
          greaterThan(4.4),
          reason: '${preset.name} ${dark ? 'dark' : 'light'}',
        );
      }
    }
  });
}
