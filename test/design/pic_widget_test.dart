import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/pic_widget.dart';

void main() {
  group('PicWidget.normalizeUrl', () {
    test('absolute and protocol-relative URLs pass through', () {
      expect(PicWidget.normalizeUrl('https://img/a.jpg'), 'https://img/a.jpg');
      expect(PicWidget.normalizeUrl('//img/a.jpg'), 'https://img/a.jpg');
    });

    test('relative paths resolve against the source base', () {
      expect(
        PicWidget.normalizeUrl('/uploads/a.jpg', base: 'https://ex.com/book/1'),
        'https://ex.com/uploads/a.jpg',
      );
      expect(
        PicWidget.normalizeUrl('uploads/a.jpg', base: 'https://ex.com/book/1'),
        'https://ex.com/book/uploads/a.jpg',
      );
      expect(
        PicWidget.normalizeUrl('//cdn/a.jpg', base: 'https://ex.com'),
        'https://cdn/a.jpg',
      );
    });

    test('relative path without a base is dropped', () {
      expect(PicWidget.normalizeUrl('/uploads/a.jpg'), isEmpty);
    });

    test('placeholders and data URIs stay empty', () {
      expect(
        PicWidget.normalizeUrl('/static/loading.jpg', base: 'https://ex.com'),
        isEmpty,
      );
      expect(
        PicWidget.normalizeUrl('data:image/png;base64,xx', base: 'https://ex.com'),
        isEmpty,
      );
      expect(PicWidget.normalizeUrl(''), isEmpty);
    });
  });

  testWidgets('missing cover renders the typographic placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PicWidget('', width: 58, height: 84, title: '琅嬛阁'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('琅'), findsOneWidget);
    expect(find.text('嬛'), findsOneWidget);
    expect(find.text('阁'), findsOneWidget);
    // The old shared placeholder asset is no longer part of the empty state.
    expect(find.byType(Image), findsNothing);
  });
}
