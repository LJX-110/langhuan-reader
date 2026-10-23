import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/reader/scroll_chapter_title.dart';

void main() {
  testWidgets('sticky chapter title keeps a full painting band', (
    tester,
  ) async {
    final chapter = ValueNotifier<String>('第一章 开端');
    addTearDown(chapter.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ScrollChapterTitle(
              chapter: chapter,
              background: const Color(0xFFFFFFFF),
              color: const Color(0xFF666666),
              topInset: 24,
              bandHeight: 36,
              horizontalPadding: 20,
            ),
          ),
        ),
      ),
    );

    expect(find.text('第一章 开端'), findsOneWidget);
    final band = tester.renderObject<RenderBox>(
      find.byType(ScrollChapterTitle),
    );
    expect(band.size.height, 60);

    chapter.value = '第二章 远行';
    await tester.pump();
    expect(find.text('第二章 远行'), findsOneWidget);
    expect(find.text('第一章 开端'), findsNothing);
  });
}
