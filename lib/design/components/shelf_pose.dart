import 'package:flutter/widgets.dart';

import 'package:langhuan/design/components/shelf_geometry.dart';

/// 书架的「姿态」：滚动位置是唯一的时钟。
///
/// 抽出波、行内弧线、入场装配全部由 [focus]（分数格位）推出来，所以滑动、
/// 点按聚焦与入场动画共用同一条时间轴，谁也不另起定时器；拖动排序的位移
/// 也挂在这里。渲染对象只监听这一个来源，滚动时是纯绘制，不重建组件树。
class ShelfPose extends ChangeNotifier {
  ShelfPose({required this.count});

  /// 书目数量。书架是有限的：首尾不循环，两端就是两端。
  int count;

  /// 分数格位：整数表示某本书停在正中，小数出现在拖动和惯性里。
  double focus = 0;

  /// 视口宽度与一格步长，由布局喂进来（布局阶段也能安全改写）。
  double viewport = 340;
  double pitch = ShelfGeometry.pitch(340);

  /// 入场装配进度 0→1。
  double entrance = 1;

  /// 拖动排序：被拿起的格位、横向位移、插入位置。
  int? grabbed;
  double grabDx = 0;
  int? dropTarget;

  /// 懒加载窗口半径（格位），由 [configure] 按视口几何算出。
  int windowRadius = _minWindowRadius;

  /// 布局正在换宽度：这一次的位置修正不该被当成一次手势落位。
  bool holdLayoutFocus = false;

  static const int _minWindowRadius = 8;
  static const double _crestStart = .38;
  static const double _assemblyReach = 56;

  /// 最后一格的序号。
  int get lastSlot => count < 1 ? 0 : count - 1;

  void configure(double width, double nextPitch) {
    if (!width.isFinite || width <= 0 || nextPitch <= 0) return;
    viewport = width;
    pitch = nextPitch;
    final spine = ShelfGeometry.spineWidth(width);
    final cover = ShelfGeometry.coverWidth(width);
    // 行首到行尾之外，还要盖住被抽出的那本向左伸出的部分。
    final reach =
        width / 2 +
        ShelfGeometry.footprint(spine, cover) +
        ShelfGeometry.pull(cover, 1) * ShelfGeometry.depthX;
    final needed = (reach / nextPitch).ceil() + 2;
    windowRadius = needed < _minWindowRadius ? _minWindowRadius : needed;
  }

  /// 把分数格位移动到 [next]（会被钳在首尾之内）。
  ///
  /// 布局阶段用 `notify: false`：位置由滚动像素得出，不需要再回调一次。
  void move(double next, {bool notify = true}) {
    final limit = lastSlot.toDouble();
    final clamped = count < 2 ? 0.0 : next.clamp(0.0, limit);
    if ((focus - clamped).abs() < .000001) return;
    focus = clamped;
    if (notify) notifyListeners();
  }

  /// 入场装配进度；滚动或点按时由页面推到 1。
  void present(double value) {
    if ((entrance - value).abs() < .000001) return;
    entrance = value;
    notifyListeners();
  }

  /// 抽出波权重：中心的书为 1，[ShelfGeometry.waveRadius] 之外为 0。
  ///
  /// 入场装配期间整体收力，避免「书还没排好就抽出来」。
  double weightAt(int slot) => ShelfGeometry.wave(slot - focus) * _crest;

  double get _crest => entrance >= 1
      ? 1
      : Interval(
          _crestStart,
          1,
          curve: Curves.easeOutCubic,
        ).transform(entrance.clamp(0.0, 1.0));

  /// 入场位移：每本书沿自己的深度轴从后场推上来，按行列顺序错开。
  Offset assemblyOffset(int slot) {
    if (entrance >= 1) return Offset.zero;
    final order = ((slot - focus) + viewport / pitch / 2 + 2).clamp(0.0, 16.0);
    final start = order * .018;
    final progress = Interval(
      start,
      start + .52,
      curve: Curves.easeOutCubic,
    ).transform(entrance.clamp(0.0, 1.0));
    final distance = _assemblyReach * (1 - progress);
    return Offset(
      ShelfGeometry.depthX * distance,
      ShelfGeometry.depthY * distance,
    );
  }

  /// 需要真实构建的槽位区间，左闭右开。
  ///
  /// 窗口跟着中心走并在两端收口：两端就是两端，不会绕回另一头去建书。
  ({int first, int end}) window() {
    if (count <= 0) return (first: 0, end: 0);
    final size = windowRadius * 2 + 1;
    final length = count < size ? count : size;
    final first = (focus.round() - windowRadius).clamp(0, count - length);
    return (first: first, end: first + length);
  }

  void beginGrab(int slot) {
    if (grabbed == slot && dropTarget == slot && grabDx == 0) return;
    grabbed = slot;
    dropTarget = slot;
    grabDx = 0;
    notifyListeners();
  }

  void updateGrab(double dx, int target) {
    if (grabbed == null) return;
    if (grabDx == dx && dropTarget == target) return;
    grabDx = dx;
    dropTarget = target;
    notifyListeners();
  }

  void endGrab() {
    if (grabbed == null && dropTarget == null && grabDx == 0) return;
    grabbed = null;
    dropTarget = null;
    grabDx = 0;
    notifyListeners();
  }
}
