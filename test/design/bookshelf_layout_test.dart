import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

List<ShelfBookView> _books(int count) {
  return List.generate(
    count,
    (i) => ShelfBookView(
      id: 'b$i',
      name: '书名 ${i + 1}',
      author: '作者 ${i + 1}',
      coverUrl: '',
    ),
  );
}

Widget _host(Brightness brightness, int count) {
  return MaterialApp(
    theme: buildLanghuanTheme(dark: brightness == Brightness.dark),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      );
    },
    home: Scaffold(
      body: SafeArea(
        child: Bookshelf3D(books: _books(count), onOpen: (_) {}),
      ),
    ),
  );
}

void main() {
  for (final count in [0, 1, 2, 5, 12]) {
    for (final width in [360.0, 411.0, 800.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          '3d shelf fits ${width.toInt()} / ${brightness.name} / $count books',
          (tester) async {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = Size(width, 800);
            addTearDown(tester.view.reset);

            await tester.pumpWidget(_host(brightness, count));
            await tester.pump();

            expect(tester.takeException(), isNull);
            expect(find.byType(Bookshelf3D), findsOneWidget);
            if (count == 0) {
              expect(find.textContaining('书名'), findsNothing);
            } else {
              // The focused volume and the meta line both carry the name.
              expect(find.text('书名 1'), findsWidgets);
            }
          },
        );
      }
    }
  }
}
