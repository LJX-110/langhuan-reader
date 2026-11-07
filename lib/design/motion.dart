import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// 统一动效词汇表 —— 对齐轻小说文库的 `NovelMotion`。
///
/// 全应用只从这里取时长 / 曲线 / 弹簧；页面里不再手写 Duration。
/// 参考：参考\Wenku8-Local-main\lib\motion_ui.dart:14-37。
abstract final class AppMotion {
  /// 按压 / 点按类即时反馈。
  static const contact = Duration(milliseconds: 120);

  /// 常规入场。
  static const enter = Duration(milliseconds: 420);

  /// 退场。
  static const exit = Duration(milliseconds: 320);

  /// 列表定位 / 落位类稳定时长。
  static const settle = Duration(milliseconds: 280);

  /// 封面飞行（去 / 回）。
  static const coverFlight = Duration(milliseconds: 1000);
  static const coverReturn = Duration(milliseconds: 840);

  /// 书架入库：整排从后场推上来。
  static const shelfEntry = Duration(milliseconds: 720);

  static const reveal = enter;

  /// 进入类曲线 / 退出类曲线 / 落位回弹曲线。
  static const ease = Curves.easeOutCubic;
  static const retract = Curves.easeInCubic;
  static const settleCurve = Cubic(.2, 1.08, .34, 1);

  /// 点按 / 落位弹簧（对齐文库质量 0.64 / 刚度 270 / 阻尼 19）。
  static const spring = SpringDescription(
    mass: .64,
    stiffness: 270,
    damping: 19,
  );

  /// 文本抖动函数（标题 / 菜单点按用），对齐文库 `NovelMotion.jelly`。
  static double jelly(double t) =>
      math.sin(t * math.pi * 3) * (1 - t) * (1 - t);
}
