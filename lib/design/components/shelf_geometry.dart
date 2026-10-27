import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 3D 书架的纯几何。
///
/// 整排书共用一套斜投影：书脊是一块切变过的平行四边形，封面从书脊顶边
/// 沿深度向量向后铺开，被「抽出」的那本沿同一深度向量向左上推出并抬起。
/// 这里只有数字和算式，渲染与测试共用同一份来源。
abstract final class ShelfGeometry {
  /// 斜投影的深度向量：向右 .66、向上 .30（屏幕 y 轴朝下，所以为负）。
  static const double depthX = .66;
  static const double depthY = -.30;

  /// 书脊顶边相对底边右移的比例，让整排书立在同一个斜面上。
  static const double spineShear = .10;

  /// 相邻格位的横向步长 = 书脊宽 + 这道缝。
  static const double slotGap = 11;

  /// 抽出波的半径（单位：格位）。再远的书完全收回，只当书脊排。
  static const double waveRadius = 1.48;

  /// 完全抽出时的行程（相对封面宽）与抬起量（相对书高）。
  static const double pullRatio = .84;
  static const double liftRatio = .60;

  /// 行框顶端到静止书顶的距离（相对书高），以及行框底部留白。
  static const double seatRatio = .60;
  static const double rowPadding = 44;

  /// 行内弧线：远端每格下沉的斜率与曲率，以及封顶距离。
  static const double rowStep = 2.5;
  static const double rowCurve = .45;
  static const double rowMaxDistance = 7;

  static double spineWidth(double width) => (width * .043).clamp(14.0, 18.0);

  static double pitch(double width) => spineWidth(width) + slotGap;

  static double coverWidth(double width) => (width * .32).clamp(100.0, 128.0);

  /// 书身高度：封面图（118:166）加上下两道档案栏位。
  static double bodyHeight(double cover) => (cover - 20) * 166 / 118 + 54;

  /// 一本静止的书从书脊左边到封面右边、在屏幕上的横向宽度。
  static double footprint(double spine, double cover) => spine + cover * depthX;

  /// 顶面在书脊顶边之上撑起的高度。
  static double topInset(double cover) => -cover * depthY;

  /// 静止时书顶在行框内的纵向位置：书坐在行框下半部，抽出时才上浮。
  static double seatY(double height) => height * seatRatio + 12;

  /// 抽出波权重：中心为 1，[waveRadius] 处为 0，中间按 cos² 收口。
  static double wave(double distance) {
    final d = distance.abs();
    if (d >= waveRadius) return 0;
    final value = math.cos(d / waveRadius * math.pi / 2);
    return value * value;
  }

  /// 抽出行程：越靠中心拉得越远，末段稍微收力，避免相邻两本撞在一起。
  static double pull(double cover, double weight) =>
      cover * pullRatio * weight * (1.24 - .24 * weight);

  /// 抬起量：smoothstep，书是被「抬起」而不是沿斜线平移。
  static double lift(double height, double weight) =>
      height * liftRatio * (weight * weight * (3 - 2 * weight));

  /// 抽出位移（相对静止位置）：沿深度向量推出，再整体抬起。
  static Offset extraction(double cover, double height, double weight) {
    final distance = pull(cover, weight);
    return Offset(
      -distance * depthX,
      -distance * depthY - lift(height, weight),
    );
  }

  /// 行内弧线：以中心为最低点，向两侧对称下沉，远端封顶。
  static double railY(double distance) {
    final d = distance.clamp(-rowMaxDistance, rowMaxDistance);
    return d * rowStep + d * d * rowCurve;
  }
}

/// 某个视口尺寸下解析出来的一套书架尺寸。
///
/// 与 [ShelfGeometry] 分开的原因：几何是常量算术，这一层是「这次布局用的是多少」，
/// 组件、渲染对象与测试都从这里取值，避免三处各算一遍。
class ShelfMetrics {
  const ShelfMetrics({
    required this.viewport,
    required this.spineW,
    required this.coverW,
    required this.bodyH,
    required this.metaHeight,
  });

  /// 书架视口宽度（行内步长、书脊与封面尺寸都由它推出）。
  final double viewport;

  /// 书脊条宽度；静止的书在行内只剩这一条加一道封面缝。
  final double spineW;

  /// 封面面板宽度（抽出后按深度向量压缩到 `coverW * depthX`）。
  final double coverW;

  /// 书身高度（封面本身；顶面画在它上方）。
  final double bodyH;

  /// 行框下方留给书名 / 作者 / 计数的高度。
  final double metaHeight;

  factory ShelfMetrics.forSize(Size size, {double metaHeight = 76}) {
    // 视口可能是无限宽（放进 ListView 之类的宽松约束），几何先收在一个合理宽度里。
    final width = size.width.isFinite ? math.max(size.width, 240.0) : 360.0;
    final cover = ShelfGeometry.coverWidth(width);
    return ShelfMetrics(
      viewport: width,
      spineW: ShelfGeometry.spineWidth(width),
      coverW: cover,
      bodyH: ShelfGeometry.bodyHeight(cover),
      metaHeight: metaHeight,
    );
  }

  /// 一格步长：静止的书在行内按这个间距排列。
  double get pitch => ShelfGeometry.pitch(viewport);

  /// 一本静止的书的横向投影宽度。
  double get footprint => ShelfGeometry.footprint(spineW, coverW);

  /// 静止书顶到书脊顶边的距离（顶面撑起的高度）。
  double get topInset => ShelfGeometry.topInset(coverW);

  /// 静止书顶在行框内的纵向位置。
  double get seatY => ShelfGeometry.seatY(bodyH);

  /// 一格书位（含顶面与书脊切变）占用的高度。
  double get volumeH =>
      topInset + bodyH + ShelfGeometry.spineShear * spineW;

  /// 行框总高度：静止站位 + 抽出上浮的余量 + 底部留白。
  double get rowHeight => seatY + volumeH + ShelfGeometry.rowPadding;

  /// 封面面板里的图片尺寸（面板上下各留一行档案位）。
  double get coverImageW => coverW - 20;

  double get coverImageH => coverImageW * 166 / 118;
}
