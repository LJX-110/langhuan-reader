import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

Widget _host(Brightness brightness) {
  final books = List.generate(
    5,
    (i) => SearchItem(name: '书名 ${i + 1}', author: '作者 ${i + 1}'),
  );
  return MaterialApp(
    theme: buildLanghuanTheme(dark: brightness == Brightness.dark),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
        ),
        child: child!,
      );
    },
    home: Scaffold(
      body: SafeArea(
        child: Bookshelf3D(books: books, onOpen: (_) {}),
      ),
    ),
  );
}

void main() {
  for (final width in [360.0, 411.0, 800.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        '3d shelf fits ${width.toInt()} / ${brightness.name}',
        (tester) async {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(brightness));
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
