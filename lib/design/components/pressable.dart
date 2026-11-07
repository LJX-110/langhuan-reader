import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/design/motion.dart';

/// 统一可按压表面（对齐文库 `JellyTapSurface`）。
///
/// 按压时轻微收缩 + 触感反馈，无水波纹；长按同样可用。
/// 全应用只在这里使用 [InkWell]，页面里不再直接写。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  /// 点按是否触发 selectionClick 触感（纯视觉行可关掉）。
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _pressed && !reduceMotion ? .985 : 1,
      duration: reduceMotion
          ? Duration.zero
          : (_pressed ? AppMotion.contact : AppMotion.enter),
      curve: AppMotion.settleCurve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          borderRadius: widget.borderRadius,
          customBorder: widget.customBorder,
          onHighlightChanged: enabled
              ? (pressed) => setState(() => _pressed = pressed)
              : null,
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onLongPress!();
                },
          child: widget.child,
        ),
      ),
    );
  }
}
