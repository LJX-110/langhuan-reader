import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/design/motion.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// Four-tab dock used by [MainShell].
///
/// 对齐轻小说文库的底栏版式：**居中的悬浮胶囊**（不是通栏横条）。
/// 结构 = 图标 20 + 11px 文字 + 12x1.5 下划线；颜色随选中态过渡。
/// 保持实色（AGENTS：不用模糊 / 玻璃）。
class LanhuanDock extends StatelessWidget {
  const LanhuanDock({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _labels = ['书架', '发现', '本地', '我'];

  /// 胶囊尺寸：宽 = 4 格 x 64，高 54（对齐 Wenku8 三格 196x54 的比例）。
  static const double dockHeight = 54;
  static const double dockWidth = 256;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final active = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);
    final inactive = dark ? AppColors.textMutedDark : AppColors.inkMute;

    return Container(
      width: dockWidth,
      height: dockHeight,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dockHeight / 2),
        border: Border.all(color: line, width: .5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14141414),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dockHeight / 2),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: _DockItem(
                  label: _labels[i],
                  icon: _DockIcon.values[i],
                  active: index == i,
                  activeColor: active,
                  companionColor: companion,
                  inactiveColor: inactive,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DockIcon { shelf, discover, local, profile }

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.companionColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final _DockIcon icon;
  final bool active;
  final Color activeColor;
  final Color companionColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点按即时触感（对齐文库 dock 的 selectionClick）。
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: activeColor.withValues(alpha: .08),
          highlightColor: activeColor.withValues(alpha: .04),
          child: SizedBox(
            height: LanhuanDock.dockHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(20, 20),
                  painter: _DockIconPainter(icon: icon, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1,
                    fontFamily: AppType.sans,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: AppMotion.contact,
                  width: active ? 12 : 0,
                  height: 1.5,
                  color: companionColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIconPainter extends CustomPainter {
  const _DockIconPainter({required this.icon, required this.color});

  final _DockIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;

    switch (icon) {
      case _DockIcon.shelf:
        canvas.drawRect(
          Rect.fromLTWH(w * .16, h * .18, w * .68, h * .68),
          paint,
        );
        canvas.drawLine(
          Offset(w * .35, h * .18),
          Offset(w * .35, h * .86),
          paint,
        );
        canvas.drawLine(
          Offset(w * .55, h * .26),
          Offset(w * .55, h * .86),
          paint,
        );
        canvas.drawLine(
          Offset(w * .72, h * .18),
          Offset(w * .72, h * .86),
          paint,
        );
        canvas.drawLine(
          Offset(w * .22, h * .38),
          Offset(w * .30, h * .38),
          paint,
        );
        canvas.drawLine(
          Offset(w * .60, h * .52),
          Offset(w * .68, h * .52),
          paint,
        );
        break;
      case _DockIcon.discover:
        canvas.drawCircle(Offset(w * .5, h * .5), w * .35, paint);
        final needle = Path()
          ..moveTo(w * .62, h * .31)
          ..lineTo(w * .54, h * .54)
          ..lineTo(w * .31, h * .62)
          ..lineTo(w * .39, h * .39)
          ..close();
        canvas.drawPath(needle, paint);
        canvas.drawCircle(Offset(w * .5, h * .5), w * .035, paint);
        break;
      case _DockIcon.local:
        final folder = Path()
          ..moveTo(w * .16, h * .28)
          ..lineTo(w * .43, h * .28)
          ..lineTo(w * .51, h * .38)
          ..lineTo(w * .84, h * .38)
          ..lineTo(w * .84, h * .80)
          ..lineTo(w * .16, h * .80)
          ..close();
        canvas.drawPath(folder, paint);
        canvas.drawLine(
          Offset(w * .16, h * .45),
          Offset(w * .84, h * .45),
          paint,
        );
        break;
      case _DockIcon.profile:
        canvas.drawCircle(Offset(w * .5, h * .34), w * .105, paint);
        final shoulders = Path()
          ..moveTo(w * .25, h * .79)
          ..quadraticBezierTo(w * .29, h * .54, w * .5, h * .54)
          ..quadraticBezierTo(w * .71, h * .54, w * .75, h * .79);
        canvas.drawPath(shoulders, paint);
        canvas.drawLine(
          Offset(w * .38, h * .79),
          Offset(w * .62, h * .79),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DockIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
