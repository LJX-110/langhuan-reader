import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Pure layout maths for the 3D shelf.
///
/// Keeping the numbers out of the widget means the unit tests and the widget
/// tests share one source of truth, and the drag/snap maths can be exercised
/// without pumping frames.
class ShelfMetrics {
  const ShelfMetrics({
    required this.width,
    required this.height,
    required this.coverW,
    required this.spineW,
    required this.bodyH,
    required this.railY,
    required this.metaHeight,
    required this.depthX,
    required this.depthY,
  });

  /// Shelf viewport width / height (the widget's constraints).
  final double width;
  final double height;

  /// Front cover width of the focused volume.
  final double coverW;

  /// Spine strip width; side volumes compress to this (plus a sliver of the
  /// turned cover).
  final double spineW;

  /// Volume height (cover only; the top face is drawn above it).
  final double bodyH;

  /// Y of the shelf rail (books stand on it).
  final double railY;

  /// Space reserved under the rail for the focused title / author / progress.
  final double metaHeight;

  /// How far the top face leans towards the outer side and up.
  final double depthX;
  final double depthY;

  /// Spine + cover box of one volume when it faces the reader.
  double get boxW => spineW + coverW;

  /// Gap between adjacent volumes in the side band.
  double get slotGap => 10;

  /// One step of shelf scrolling: the side band packs at spine pitch.
  double get snapPitch => spineW + slotGap;

  /// Total paint width of a volume including its top face.
  double get volumeW => boxW + depthX;

  /// Total paint height of a volume including its top face.
  double get volumeH => bodyH + depthY;

  factory ShelfMetrics.forSize(Size size, {double metaHeight = 76}) {
    final w = math.max(size.width, 240.0);
    final coverW = (w * 0.32).clamp(100.0, 132.0);
    final spineW = (w * 0.043).clamp(14.0, 18.0);
    // The top face leans a little less than the audit draft so it does not
    // cover the neighbouring volume on narrow screens.
    final depthX = coverW * 0.42;
    final depthY = coverW * 0.20;
    final bodyH = coverW * 166 / 118;
    final railY = math.max(
      bodyH + 44,
      math.max(size.height, 320.0) - metaHeight - 14,
    );
    return ShelfMetrics(
      width: size.width,
      height: size.height,
      coverW: coverW,
      spineW: spineW,
      bodyH: bodyH,
      railY: railY,
      metaHeight: metaHeight,
      depthX: depthX,
      depthY: depthY,
    );
  }

  /// Unsigned yaw (radians) at a fractional distance [x] from the focus.
  ///
  /// 0 → facing the reader; 1 → already a narrow angled cover; beyond that the
  /// spine carries the row until the angle caps at ~81°.
  double yawAbsForD(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return math.min(1.42, 1.15 + 0.27 * (x - 1));
    return 1.15 * x;
  }

  /// Signed yaw for the slot [d] steps away from the focused book; the sign
  /// is the side (positive = right of centre).
  double yawForD(double d) => d < 0 ? -yawAbsForD(-d) : yawAbsForD(d);

  /// Yaw of the integer slot [d] — kept for the geometry tests.
  double yawFor(int d) => yawForD(d.toDouble());

  /// Screen-space width of the volume at [d] after it turns away.
  double visibleWidthForD(double d) {
    if (d == 0) return boxW;
    return spineW + coverW * math.cos(yawAbsForD(d.abs()));
  }

  double visibleWidthFor(int d) => visibleWidthForD(d.toDouble());

  /// Y offset: distant volumes sink slightly so the row reads as an arc.
  double yForD(double d) => (d.abs() * 2.5 + d * d * 0.45);

  /// Left edge (screen space) of the volume box at fractional slot [d].
  ///
  /// Mirrors the right side around the centre so both sides stay symmetric
  /// while dragging.
  double xForD(double d) {
    if (d >= 0) return _rightX(d);
    final steps = -d;
    return width - _rightX(steps) - visibleWidthForD(steps);
  }

  /// Whether the volume at [d] is drawn mirrored (spine on the right) so its
  /// spine faces the focused book.
  bool mirrorFor(int d) => d < 0;

  double _rightX(double d) {
    final first = width / 2 - boxW / 2; // slot 0 left edge
    final sideStart = width / 2 + boxW / 2 + slotGap; // slot +1 left edge
    if (d <= 1) return first + (sideStart - first) * d;
    var x = sideStart;
    var k = 1;
    final target = d;
    while (k < target) {
      final step = visibleWidthFor(k) + slotGap;
      final remaining = target - k;
      if (remaining >= 1) {
        x += step;
        k += 1;
      } else {
        x += step * remaining;
        break;
      }
    }
    return x;
  }
}
