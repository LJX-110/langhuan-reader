import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/shelf_geometry.dart';
import 'package:langhuan/design/components/shelf_pose.dart';

void main() {
  for (final width in [360.0, 411.0, 800.0]) {
    test('metrics stay in range at ${width.toInt()}', () {
      final m = ShelfMetrics.forSize(Size(width, 640));

      expect(m.coverW, inInclusiveRange(100, 132));
      expect(m.spineW, inInclusiveRange(14, 18));
      expect(m.pitch, greaterThan(m.spineW));
      expect(m.bodyH, greaterThan(m.coverW));
      // 行框装得下静止的书，抽出上浮之后书顶也不会越过行框顶端。
      expect(m.rowHeight, greaterThan(m.volumeH));
      expect(m.seatY, greaterThan(0));
      expect(m.seatY + m.volumeH, lessThanOrEqualTo(m.rowHeight));
      expect(
        m.seatY + ShelfGeometry.extraction(m.coverW, m.bodyH, 1).dy,
        greaterThan(0),
      );
      // 书身包含顶面：一格书位比书身更高。
      expect(m.volumeH, greaterThan(m.bodyH));
      // 斜投影把封面压窄，一格的横向投影落在书脊与整本封面之间。
      expect(m.footprint, greaterThan(m.spineW));
      expect(m.footprint, lessThan(m.spineW + m.coverW));
      // 封面图连同上下的档案栏位正好落在书身里。
      expect(m.coverImageH, lessThanOrEqualTo(m.bodyH));
    });
  }

  test('抽出波在中心最强、半径外归零', () {
    expect(ShelfGeometry.wave(0), 1);
    expect(ShelfGeometry.wave(ShelfGeometry.waveRadius), 0);
    expect(ShelfGeometry.wave(3), 0);
    // 越靠中心抽得越出，且左右对称。
    expect(ShelfGeometry.wave(.5), greaterThan(ShelfGeometry.wave(1)));
    expect(ShelfGeometry.wave(1), greaterThan(ShelfGeometry.wave(1.4)));
    expect(
      ShelfGeometry.wave(-.7),
      closeTo(ShelfGeometry.wave(.7), .0001),
    );
  });

  test('抽出的书朝左上离场，行程随权重单调', () {
    final m = ShelfMetrics.forSize(const Size(400, 640));

    expect(ShelfGeometry.extraction(m.coverW, m.bodyH, 0), Offset.zero);
    final half = ShelfGeometry.extraction(m.coverW, m.bodyH, .5);
    final full = ShelfGeometry.extraction(m.coverW, m.bodyH, 1);
    // 抽出是向左上：横向朝左、纵向抬起（屏幕 y 变小）。
    expect(half.dx, lessThan(0));
    expect(half.dx, greaterThan(full.dx));
    expect(half.dy, lessThan(0));
    expect(full.dy, lessThan(half.dy));
    expect(
      ShelfGeometry.pull(m.coverW, .5),
      lessThan(ShelfGeometry.pull(m.coverW, 1)),
    );
    // 抽出行程不超过一格书位：邻书不会被抽出来的那本盖死。
    expect(-full.dx, lessThan(m.footprint));
  });

  test('行内弧线向右下沉、向左轻微抬起、远端封顶', () {
    expect(ShelfGeometry.railY(0), 0);
    expect(ShelfGeometry.railY(2), greaterThan(ShelfGeometry.railY(1)));
    expect(ShelfGeometry.railY(-1), lessThan(0));
    expect(ShelfGeometry.railY(-2).abs(), lessThan(ShelfGeometry.railY(2)));
    expect(ShelfGeometry.railY(9), closeTo(ShelfGeometry.railY(7), .0001));
    expect(ShelfGeometry.railY(-9), closeTo(ShelfGeometry.railY(-7), .0001));
  });

  test('有限书架：窗口跟着中心走，两端收口', () {
    final pose = ShelfPose(count: 500)
      ..configure(400, ShelfGeometry.pitch(400));

    expect(pose.windowRadius, greaterThanOrEqualTo(8));
    pose.move(250);
    final middle = pose.window();
    expect(middle.first, lessThanOrEqualTo(250));
    expect(middle.end, greaterThan(250));
    // 只建可视窗口，不是整柜。
    expect(middle.end - middle.first, lessThanOrEqualTo(pose.windowRadius * 2 + 1));
    expect(middle.end - middle.first, lessThan(500));

    pose.move(0);
    expect(pose.window().first, 0);
    pose.move(499);
    expect(pose.window().end, 500);
  });

  test('分数格位被钳在首尾之内，单本永远在正中', () {
    final pose = ShelfPose(count: 3)
      ..configure(400, ShelfGeometry.pitch(400));
    pose.move(-2);
    expect(pose.focus, 0);
    pose.move(9);
    expect(pose.focus, 2);

    final single = ShelfPose(count: 1);
    single.move(5);
    expect(single.focus, 0);
    expect(single.window(), (first: 0, end: 1));
  });
}
