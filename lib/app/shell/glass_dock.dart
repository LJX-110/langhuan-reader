import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// Three-tab bottom bar used by [MainShell].
///
/// White surface, one hairline, and a colour change for the active tab. No
/// pill, no blur: the dock should disappear behind the page.
class LanhuanDock extends StatelessWidget {
  const LanhuanDock({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const _labels = ['书架', '发现', '本地', '我'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final active = Theme.of(context).colorScheme.primary;
    final inactive = dark ? const Color(0xFFB3B3B3) : AppColors.inkMute;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: line, width: .5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08141414),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(
                  child: _DockItem(
                    label: _labels[i],
                    icon: _DockIcon.values[i],
                    active: index == i,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: activeColor.withValues(alpha: .08),
          highlightColor: activeColor.withValues(alpha: .04),
          child: SizedBox(
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(22, 22),
                  painter: _DockIconPainter(icon: icon, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    height: 1,
                    letterSpacing: .4,
                    fontFamily: AppType.sans,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
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
