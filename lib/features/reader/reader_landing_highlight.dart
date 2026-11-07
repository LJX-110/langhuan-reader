import 'package:flutter/material.dart';

/// Bookmark landing cue: a temporary registration plane around the body.
///
/// A solid border + faint paper wash, no glow or blur. It fades in quickly,
/// holds, then fades out; reduced-motion keeps a static plane.
class ReaderLandingHighlight extends StatelessWidget {
  const ReaderLandingHighlight({
    super.key,
    this.reduceMotion = false,
    this.color,
  });

  final bool reduceMotion;

  /// Border / wash colour; defaults to the theme accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1800),
      curve: Curves.linear,
      builder: (context, t, _) => IgnorePointer(
        child: CustomPaint(
          painter: _LandingPlane(strength: landingStrength(t), color: color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 0→1 strength curve: quick in (12%), hold, then fade out after 70%.
double landingStrength(double t) {
  if (t <= 0) return 0;
  if (t < .12) return Curves.easeOut.transform(t / .12);
  if (t < .7) return 1;
  return 1 - Curves.easeInOut.transform(((t - .7) / .3).clamp(0.0, 1.0));
}

class _LandingPlane extends CustomPainter {
  _LandingPlane({required this.strength, required this.color});

  final double strength;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rect = Rect.fromLTWH(-6, -3, size.width + 12, size.height + 6);
    final radius = Radius.circular(12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = color.withValues(alpha: strength * .06),
    );
    final rule = Paint()
      ..color = color.withValues(alpha: strength * .42)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), rule);
  }

  @override
  bool shouldRepaint(_LandingPlane oldDelegate) =>
      strength != oldDelegate.strength || color != oldDelegate.color;
}
