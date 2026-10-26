import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/theme/theme_presets.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// The detail-page CTA uses `colorScheme.primary` / `onPrimary`; this guards
/// all 12 presets in both brightnesses against unreadable filled buttons.
void main() {
  for (final dark in [false, true]) {
    for (final preset in LanghuanThemes.all) {
      testWidgets(
        '${preset.name} ${dark ? 'dark' : 'light'} primary button contrast',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildLanghuanTheme(
                dark: dark,
                accent: preset.accent,
                secondaryColor: preset.secondary,
              ),
              home: const SizedBox(),
            ),
          );
          final scheme = Theme.of(
            tester.element(find.byType(SizedBox)),
          ).colorScheme;
          expect(
            AppColors.contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            AppColors.contrastRatio(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
          );
        },
      );
    }
  }
}
