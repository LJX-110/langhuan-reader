import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/theme/theme_presets.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// All 12 presets must render the 3D shelf (with badges and selection) and
/// keep readable text tokens — without changing any preset colour.
void main() {
  final books = [
    for (var i = 0; i < 5; i++)
      ShelfBookView(
        id: 'b$i',
        name: '书名 ${i + 1}',
        author: '作者 ${i + 1}',
        coverUrl: '',
        progressLabel: '读到 · 第 ${i + 1} 章',
        hasUpdate: i == 0,
      ),
  ];

  for (final dark in [false, true]) {
    for (final preset in LanghuanThemes.all) {
      testWidgets('${preset.name} ${dark ? 'dark' : 'light'} shelf renders', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(411, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLanghuanTheme(
              dark: dark,
              accent: preset.accent,
              secondaryColor: preset.secondary,
            ),
            home: Scaffold(
              body: Bookshelf3D(
                books: books,
                entryAnimation: false,
                onOpen: (_) {},
                onDelete: (_) async {},
                selectable: true,
                selectedIds: const {'b1'},
                onToggleSelect: (_) {},
                onReorder: (_, _) async {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('书名 1'), findsWidgets);

        final scheme = Theme.of(
          tester.element(find.byType(Bookshelf3D)),
        ).colorScheme;
        // Secondary type must stay readable on the page (≥ 3:1).
        expect(
          AppColors.contrastRatio(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(3.0),
        );
      });
    }
  }
}
