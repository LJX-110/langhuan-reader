import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:langhuan/design/components/shelf_geometry.dart';
import 'package:langhuan/design/components/shelf_palette.dart';
import 'package:langhuan/design/components/shelf_pose.dart';

/// 格位父数据：只用来串起一行里的书，偏移在绘制时现算。
class ShelfSlotParentData extends ContainerBoxParentData<RenderBox> {}

/// 一行书：一格一个孩子，位置在绘制时算。
///
/// 滚动只改 [ShelfPose]，渲染对象重绘即可；孩子的位置、抽出量、入场位移
/// 都在 [ShelfSceneRender] 里推出来，所以滑动过程中不重建组件树。
class ShelfScene extends MultiChildRenderObjectWidget {
  const ShelfScene({
    super.key,
    required this.offset,
    required this.pose,
    required this.metrics,
    required this.firstSlot,
    required this.palette,
    required super.children,
  });

  /// 滚动位置，也就是这条时间轴的唯一来源。
  final ViewportOffset offset;
  final ShelfPose pose;
  final ShelfMetrics metrics;

  /// 第一个孩子的格位序号（窗口左边界）。
  final int firstSlot;
  final ShelfPalette palette;

  @override
  ShelfSceneRender createRenderObject(BuildContext context) =>
      ShelfSceneRender._(offset, pose, metrics, firstSlot, palette);

  @override
  void updateRenderObject(BuildContext context, ShelfSceneRender renderObject) {
    renderObject.update(
      offset: offset,
      pose: pose,
      metrics: metrics,
      firstSlot: firstSlot,
      palette: palette,
    );
  }
}

class ShelfSceneRender extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ShelfSlotParentData> {
  ShelfSceneRender._(
    this._scrollOffset,
    this._pose,
    this._metrics,
    this._firstSlot,
    this._palette,
  );

  /// 被拿起的书抬起的高度：拖动时离地，也把自己从邻书里拔出来。
  static const double grabLift = 26;

  ViewportOffset _scrollOffset;
  ShelfPose _pose;
  ShelfMetrics _metrics;
  int _firstSlot;
  ShelfPalette _palette;

  final List<RenderBox> _boxes = <RenderBox>[];
  final List<double> _x = <double>[];
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  int debugLayoutCount = 0;
  int get debugMountedCount => childCount;
  int get debugFirstSlot => _firstSlot;
  int get debugEndSlot => _firstSlot + childCount;

  /// 有限行程：最后一本停在正中，右边就是边界。
  double get _maxExtent =>
      _pose.count < 2 ? 0 : (_pose.count - 1) * _pose.pitch;

  /// 每个格位只占一格宽：封面画出格位、压到邻书上，但命中与语义都留在这一格。
  Size get _volumeSize => Size(_metrics.pitch, _metrics.volumeH);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ShelfSlotParentData) {
      child.parentData = ShelfSlotParentData();
    }
  }

  void update({
    required ViewportOffset offset,
    required ShelfPose pose,
    required ShelfMetrics metrics,
    required int firstSlot,
    required ShelfPalette palette,
  }) {
    _scrollOffset = offset;
    if (_pose != pose) {
      if (attached) _pose.removeListener(markNeedsPaint);
      _pose = pose;
      if (attached) _pose.addListener(markNeedsPaint);
    }
    _metrics = metrics;
    _firstSlot = firstSlot;
    _palette = palette;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pose.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _pose.removeListener(markNeedsPaint);
    super.detach();
  }

  /// 静止位置：只含行内弧线与入场位移，不含抽出与拖动。
  ///
  /// 地面投影用这一份，所以书的影子始终留在行上，不会跟着书一起飞起来。
  Offset _restOffset(int childIndex) {
    final slot = _firstSlot + childIndex;
    final distance = slot - _pose.focus;
    return Offset(
          _x[childIndex] - _pose.focus * _pose.pitch,
          _metrics.seatY + ShelfGeometry.railY(distance),
        ) +
        _pose.assemblyOffset(slot);
  }

  Offset _slotOffset(int childIndex) {
    final slot = _firstSlot + childIndex;
    final extraction = ShelfGeometry.extraction(
      _metrics.coverW,
      _metrics.bodyH,
      _pose.weightAt(slot),
    );
    final grab = _pose.grabbed == slot
        ? Offset(_pose.grabDx, -grabLift)
        : Offset.zero;
    return _restOffset(childIndex) + extraction + grab;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    _scrollOffset.applyViewportDimension(size.width);
    // 视口尺寸变化时滚动位置可能自己校正一次，接受它之后再读分数格位。
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_scrollOffset.applyContentDimensions(0, _maxExtent)) break;
    }
    _pose.move(_scrollOffset.pixels / _pose.pitch, notify: false);

    _boxes.clear();
    _x.clear();
    // 行首：让完全抽出的那本书正好落在视口正中。
    final start =
        size.width / 2 -
        _metrics.footprint / 2 +
        ShelfGeometry.pull(_metrics.coverW, 1) * ShelfGeometry.depthX;
    var child = firstChild;
    while (child != null) {
      final index = _boxes.length;
      child.layout(BoxConstraints.tight(_volumeSize));
      _x.add(start + (_firstSlot + index) * _pose.pitch);
      _boxes.add(child);
      child = childAfter(child);
    }
    debugLayoutCount++;
  }

  List<int> get _visible {
    final viewport = Offset.zero & size;
    return <int>[
      for (var index = 0; index < _boxes.length; index++)
        if (viewport.overlaps(
          _boxes[index].paintBounds.shift(_slotOffset(index)),
        ))
          index,
    ];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final visible = _visible;
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) {
        _paintFloorCast(context.canvas, offset, visible);
        for (final index in visible) {
          context.paintChild(_boxes[index], offset + _slotOffset(index));
        }
        _paintDropTarget(context.canvas, offset);
      },
      oldLayer: _clipLayer.layer,
    );
  }

  /// 书底在地面上的投影：一圈淡墨，让整排书站在同一个平面上。
  void _paintFloorCast(Canvas canvas, Offset offset, List<int> visible) {
    final depth = Offset(
      _metrics.coverW * ShelfGeometry.depthX,
      _metrics.coverW * ShelfGeometry.depthY,
    );
    for (final index in visible) {
      final o =
          offset +
          _restOffset(index) +
          Offset(0, _metrics.topInset + _metrics.bodyH);
      final path = Path()
        ..addPolygon([
          o,
          o + Offset(_metrics.spineW, 1.4),
          o + Offset(_metrics.spineW, 1.4) + depth,
          o + depth,
          o + depth + const Offset(-10, 10),
          o + const Offset(-10, 10),
        ], true);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              _palette.ink.withValues(alpha: .10),
              _palette.ink.withValues(alpha: 0),
            ],
          ).createShader(path.getBounds()),
      );
    }
  }

  /// 拖动排序时的插入位置：一道竖线落在目标格位的边上。
  void _paintDropTarget(Canvas canvas, Offset offset) {
    final from = _pose.grabbed;
    final to = _pose.dropTarget;
    if (from == null || to == null || from == to) return;
    final index = to - _firstSlot;
    if (index < 0 || index >= _boxes.length) return;
    final distance = to - _pose.focus;
    final left = _x[index] - _pose.focus * _pose.pitch;
    final x = to > from ? left + _metrics.footprint : left;
    final top =
        offset.dy +
        _metrics.seatY +
        ShelfGeometry.railY(distance) +
        _metrics.topInset -
        6;
    final bottom =
        offset.dy +
        _metrics.seatY +
        ShelfGeometry.railY(distance) +
        _metrics.volumeH +
        6;
    canvas.drawLine(
      Offset(offset.dx + x, top),
      Offset(offset.dx + x, bottom),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = _palette.companion,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 后画的孩子在上面：反向遍历，和绘制顺序一致。
    for (final index in _visible.reversed) {
      if (result.addWithPaintOffset(
        offset: _slotOffset(index),
        position: position,
        hitTest: (result, position) =>
            _boxes[index].hitTest(result, position: position),
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = _slotOffset(_boxes.indexOf(child));
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  Rect describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
