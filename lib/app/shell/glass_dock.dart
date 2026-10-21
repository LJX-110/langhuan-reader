import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// Three-tab frosted dock used by [MainShell].
///
/// The dock stays deliberately low: paper surface, hairline, a single
/// qingmo-tinted pill for the active tab. No fourth tab for search — search
/// lives in the page header.
class LanhuanDock extends StatelessWidget {
  const LanhuanDock({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const _labels = ['书架', '发现', '我'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final primary = Theme.of(context).colorScheme.primary;
    final inactive = AppColors.inkMute;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: dark ? .94 : .90),
        border: Border(top: BorderSide(color: line, width: .5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1F1E1B),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.dockHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _labels.length; i++)
                _DockItem(
                  label: _labels[i],
                  icon: _DockIcon.values[i],
                  active: index == i,
                  activeColor: primary,
                  inactiveColor: inactive,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DockIcon { shelf, discover, profile }

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final _DockIcon icon;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 86,
          height: 56,
          padding: const EdgeInsets.only(top: 6, bottom: 5),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.095)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
              width: .5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(22, 22),
                painter: _DockIconPainter(icon: icon, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  height: 1,
                  letterSpacing: 1.4,
                  fontFamily: AppType.serif,
                ),
              ),
            ],
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
