import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/menu/reader_progress_bar.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// 底栏进度条：数值 / 目标 / 预览的纯计算，以及拖动、点按的回调节点。
void main() {
  group('ReaderProgress', () {
    test('valueOf maps chapter + page ratio to book progress', () {
      expect(
        ReaderProgress.valueOf(chapter: 0, pageIndex: 0, pages: 10, total: 4),
        0,
      );
      expect(
        ReaderProgress.valueOf(chapter: 0, pageIndex: 9, pages: 10, total: 4),
        0.25,
      );
      expect(
        ReaderProgress.valueOf(chapter: 2, pageIndex: 4, pages: 9, total: 4),
        0.625,
      );
      expect(
        ReaderProgress.valueOf(chapter: 3, pageIndex: 7, pages: 8, total: 4),
        1.0,
      );
      // 单页章节只占自己的章节格位。
      expect(
        ReaderProgress.valueOf(chapter: 1, pageIndex: 0, pages: 1, total: 4),
        0.25,
      );
      expect(
        ReaderProgress.valueOf(chapter: 0, pageIndex: 0, pages: 0, total: 4),
        0,
      );
    });

    test('targetOf is the inverse mapping and clamps at 100%', () {
      expect(ReaderProgress.targetOf(0, 4), (chapter: 0, ratio: 0.0));
      expect(ReaderProgress.targetOf(0.625, 4), (chapter: 2, ratio: 0.5));
      expect(ReaderProgress.targetOf(1, 4), (chapter: 3, ratio: 1.0));
      expect(ReaderProgress.targetOf(2, 4), (chapter: 3, ratio: 1.0));
      expect(ReaderProgress.targetOf(0.5, 0), (chapter: 0, ratio: 0));
    });

    test('previewOf shows 第 N 章 · X%', () {
      expect(ReaderProgress.previewOf(0, 4), '第 1 章 · 0%');
      expect(ReaderProgress.previewOf(0.25, 4), '第 2 章 · 25%');
      expect(ReaderProgress.previewOf(1, 4), '第 4 章 · 100%');
      expect(ReaderProgress.previewOf(0.5, 0), '');
    });
  });

  Widget harness({
    required double value,
    required bool dragging,
    required VoidCallback onStart,
    required ValueChanged<double> onUpdate,
    required VoidCallback onEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ReaderProgressBar(
              chrome: const ReaderChrome(PaperTheme.cream),
              value: value,
              dragging: dragging,
              previewText: '第 1 章 · 0%',
              onDragStart: onStart,
              onDragUpdate: onUpdate,
              onDragEnd: onEnd,
              onDragCancel: () {},
              onPointerCancel: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('horizontal drag reports start / update / end', (tester) async {
    var starts = 0;
    var ends = 0;
    double? last;
    await tester.pumpWidget(
      harness(
        value: 0,
        dragging: false,
        onStart: () => starts++,
        onUpdate: (v) => last = v,
        onEnd: () => ends++,
      ),
    );

    final center = tester.getCenter(find.byType(ReaderProgressBar));
    await tester.dragFrom(center, const Offset(120, 0));

    expect(starts, greaterThanOrEqualTo(1));
    expect(ends, 1);
    expect(last, isNotNull);
    expect(last! > 0.5, isTrue);
  });

  testWidgets('tap seeks then commits on release', (tester) async {
    var starts = 0;
    var ends = 0;
    double? last;
    await tester.pumpWidget(
      harness(
        value: 0,
        dragging: false,
        onStart: () => starts++,
        onUpdate: (v) => last = v,
        onEnd: () => ends++,
      ),
    );

    await tester.tap(find.byType(ReaderProgressBar));

    expect(starts, 1);
    expect(ends, 1);
    expect(last, isNotNull);
    expect(last!.abs() - 0.5, lessThan(0.01));
  });
}
