import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:langhuan/design/components/shelf_pose.dart';

/// 松手后的落位：先摩擦减速，再把剩下的行程交给一条三次曲线。
///
/// 两段共用同一个位置与速度，所以松手不会变成一次新的「归中动画」；落点
/// 始终钳在书架首尾之内，末尾不会空转。轻拨只走弹簧，格位照样对齐。
class ShelfScrollSimulation extends Simulation {
  ShelfScrollSimulation({
    required double position,
    required double velocity,
    required double pitch,
    required double min,
    required double max,
    double minimumVelocity = 50,
    super.tolerance,
  }) : assert(pitch > 0) {
    final speed = velocity.abs();
    final directional = speed >= minimumVelocity;
    final release = directional ? velocity : 0.0;
    var destination = ((position + release / _dragRate) / pitch).round() * pitch;
    // 真正的甩动应该落在前方，而不是冲过落点再倒回来：留出足够长的减速跑道。
    if (directional &&
        (destination - position) * release.sign < speed / _omega) {
      final runway = position + release / _omega;
      destination =
          (release > 0 ? (runway / pitch).ceil() : (runway / pitch).floor()) *
          pitch;
    }
    // 有限行程：落点就是首尾之间最近的格位，两端不循环。
    target = destination.clamp(min, max);
    _coast = FrictionSimulation(math.exp(-_dragRate), position, release);

    var coast = speed > pitch * _handoffRatio && directional
        ? math.log(speed / (pitch * _handoffRatio)) / _dragRate
        : 0.0;
    final gap = target - position;
    if (release != 0 && gap != 0) {
      // 减速段一旦追到落点就立刻交接，否则三次段会倒着落回去。
      final ratio = gap * _dragRate / release;
      if (ratio >= 1) {
        coast = 0; // 摩擦追不上落点：交给弹簧自己收口。
      } else {
        final crossing = -math.log(1 - ratio) / _dragRate;
        coast = crossing > 0 ? math.min(coast, crossing) : 0;
      }
    }
    final handoffPosition = _coast.x(coast);
    final handoffVelocity = _coast.dx(coast);
    final remaining = target - handoffPosition;
    // 只有「交接速度指向落点、且还剩一段路」才用三次段；其余交给弹簧。
    final landable =
        directional && handoffVelocity * remaining > 0 && remaining.abs() > .5;
    coastDuration = landable ? coast : 0;
    _handoffPosition = landable ? handoffPosition : position;
    _handoffVelocity = landable ? handoffVelocity : release;
    _landingDuration = landable ? 3 * remaining / handoffVelocity : 0;
    _restDetent = SpringSimulation(
      const SpringDescription(
        mass: 1,
        stiffness: _omega * _omega,
        damping: 2 * _omega,
      ),
      position,
      target,
      landable ? 0 : release,
      // 停在整数格位上，不留一本几乎居中的书。
      snapToEnd: true,
      tolerance: Tolerance(
        distance: math.min(tolerance.distance, .01),
        velocity: math.min(tolerance.velocity, .1),
      ),
    );
  }

  static const double _dragRate = 4.4;
  static const double _omega = 12.0;
  static const double _handoffRatio = 4;

  late final double target;
  late final double coastDuration;
  late final FrictionSimulation _coast;
  late final double _handoffPosition;
  late final double _handoffVelocity;
  late final double _landingDuration;
  late final SpringSimulation _restDetent;

  double _remaining(double time) =>
      (1 - (time - coastDuration) / _landingDuration).clamp(0.0, 1.0);

  @override
  double x(double time) {
    if (_landingDuration == 0) return _restDetent.x(time);
    if (time < coastDuration) return _coast.x(time);
    // 有限的三次落位：起点带着来速，终点速度与加速度同时归零。
    final remaining = _remaining(time);
    return target -
        (target - _handoffPosition) * remaining * remaining * remaining;
  }

  @override
  double dx(double time) {
    if (_landingDuration == 0) return _restDetent.dx(time);
    if (time < coastDuration) return _coast.dx(time);
    final remaining = _remaining(time);
    return _handoffVelocity * remaining * remaining;
  }

  @override
  bool isDone(double time) => _landingDuration == 0
      ? _restDetent.isDone(time)
      : time >= coastDuration + _landingDuration;
}

/// 书架的滚动物理：把 [ShelfScrollSimulation] 接到滚动位置上。
///
/// 内容尺寸有限（首尾就是两端），所以父级用钳制物理；视口换宽度时保留
/// 分数格位，横竖屏切换不会把中心的书甩丢。
class ShelfSnapPhysics extends ScrollPhysics {
  const ShelfSnapPhysics({
    required this.pose,
    super.parent = const ClampingScrollPhysics(),
  });

  final ShelfPose pose;

  @override
  ShelfSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      ShelfSnapPhysics(pose: pose, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (!oldPosition.hasViewportDimension ||
        oldPosition.viewportDimension <= 0) {
      return newPosition.pixels.clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    // 视口换了宽度：按旧步长取回分数格位，再用新步长落位。
    final focus = newPosition.pixels / pose.pitch;
    if (!isScrolling &&
        oldPosition.viewportDimension != newPosition.viewportDimension) {
      pose.holdLayoutFocus = true;
    }
    final next = pose.pitch > 0 ? focus * pose.pitch : newPosition.pixels;
    return next.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (pose.holdLayoutFocus && velocity == 0) {
      pose.holdLayoutFocus = false;
      return null;
    }
    pose.holdLayoutFocus = false;
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final simulation = ShelfScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      pitch: pose.pitch,
      min: position.minScrollExtent,
      max: position.maxScrollExtent,
      minimumVelocity: minFlingVelocity,
      tolerance: toleranceFor(position),
    );
    if ((simulation.target - position.pixels).abs() < .01 && velocity == 0) {
      return null;
    }
    return simulation;
  }
}
