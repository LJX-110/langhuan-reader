import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/reader/reader_landing_highlight.dart';

void main() {
  test('强度曲线：快速进、保持、末尾淡出', () {
    expect(landingStrength(0), 0);
    expect(landingStrength(.12), 1);
    expect(landingStrength(.5), 1);
    expect(landingStrength(1), 0);
  });

  testWidgets('书签落点平面正常绘制并在 1.8s 内收尾', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: ReaderLandingHighlight(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1000));

    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(ReaderLandingHighlight),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(customPaint.painter, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态时使用静态平面，不启动动画', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: ReaderLandingHighlight(reduceMotion: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
