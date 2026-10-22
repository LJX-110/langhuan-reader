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

  test('bright and dark accents stay readable', () {
    final light = buildLanghuanTheme(
      dark: false,
      accent: const Color(0xFFFFFF00),
    );
    expect(_contrast(light.colorScheme.primary, Colors.white), greaterThan(4.4));

    final dark = buildLanghuanTheme(
      dark: true,
      accent: const Color(0xFF470125),
    );
    expect(_contrast(dark.colorScheme.primary, Colors.black), greaterThan(4.4));
  });
}
