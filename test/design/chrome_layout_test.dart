import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/app/shell/glass_dock.dart';
import 'package:langhuan/design/components/archive_header.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

Widget _host({
  required Widget child,
  required Brightness brightness,
}) {
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
        child: Column(
          children: [
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}

Widget _shelfChrome() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ArchiveBrandBar(
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            tooltip: '模式',
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () {},
          ),
          IconButton(
            tooltip: '整理',
            icon: const Icon(Icons.checklist_rtl),
            onPressed: () {},
          ),
        ],
      ),
      const ArchiveLabel('01 / 藏书'),
      const ArchiveTitle(title: '书架', subtitle: '共 12 本 · 私人书阁'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: PaperSearchEntry(onTap: () {}),
      ),
    ],
  );
}

void main() {
  for (final width in [360.0, 411.0, 800.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('chrome fits ${width.toInt()} / ${brightness.name}', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(child: _shelfChrome(), brightness: brightness),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _host(
            brightness: brightness,
            child: LanhuanDock(index: 0, onTap: (_) {}),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
