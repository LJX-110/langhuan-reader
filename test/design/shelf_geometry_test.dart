import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/shelf_geometry.dart';

void main() {
  for (final width in [360.0, 411.0, 800.0]) {
    test('metrics stay in range at ${width.toInt()}', () {
      final m = ShelfMetrics.forSize(Size(width, 640));

      expect(m.coverW, inInclusiveRange(100, 132));
      expect(m.spineW, inInclusiveRange(14, 18));
      expect(m.snapPitch, greaterThan(m.spineW));
      expect(m.bodyH, greaterThan(m.coverW));
      expect(m.railY, greaterThanOrEqualTo(m.bodyH + 44 - 0.001));
      expect(m.volumeW, greaterThan(m.boxW));
      expect(m.volumeH, greaterThan(m.bodyH));
      // The top face must not reach above the widget.
      expect(m.railY - m.bodyH - m.depthY, greaterThanOrEqualTo(0));
    });
  }

  test('finite shelf layout is symmetric and monotonic', () {
    final m = ShelfMetrics.forSize(const Size(400, 640));

    expect(m.yawFor(0), 0);
    expect(m.mirrorFor(-1), isTrue);
    expect(m.mirrorFor(1), isFalse);

    // Side volumes compress; the compression never grows again.
    expect(m.visibleWidthFor(1), lessThan(m.boxW));
    expect(
      m.visibleWidthFor(3),
      lessThanOrEqualTo(m.visibleWidthFor(1) + 0.001),
    );
    expect(m.visibleWidthFor(2), lessThan(m.visibleWidthFor(1)));

    // Centre book is centred.
    expect(m.xForD(0), closeTo(m.width / 2 - m.boxW / 2, 0.001));

    // Left side mirrors the right side around the centre.
    final left = m.xForD(-1);
    final right = m.xForD(1);
    expect(left, closeTo(m.width - right - m.visibleWidthFor(1), 0.001));

    // Adjacent side spines keep at least a spine width of distance, and the
    // side band stays inside plausible bounds.
    expect(m.xForD(2) - m.xForD(1), greaterThanOrEqualTo(m.spineW));
    expect(m.xForD(1), greaterThan(m.width / 2));
  });

  test('fractional slots interpolate between whole slots', () {
    final m = ShelfMetrics.forSize(const Size(400, 640));
    final half = m.xForD(0.5);

    expect(half, greaterThan(m.xForD(0)));
    expect(half, lessThan(m.xForD(1)));
    expect(m.yawAbsForD(0.5), lessThan(m.yawAbsForD(1)));
    expect(m.yawAbsForD(9), lessThanOrEqualTo(1.42 + 0.001));
  });
}
