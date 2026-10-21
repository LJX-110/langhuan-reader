import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// The small cinnabar seal used as the app's mark in chrome.
class SealMark extends StatelessWidget {
  const SealMark({
    super.key,
    this.size = 32,
    this.text = '琅',
    this.filled = true,
  });

  final double size;
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.seal : Colors.transparent;
    final foreground = filled ? AppColors.paperLight : AppColors.seal;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: filled
              ? AppColors.seal.withValues(alpha: .35)
              : AppColors.seal.withValues(alpha: .55),
          width: .5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * .12),
        child: FittedBox(
          child: Text(
            text,
            style: TextStyle(
              color: foreground,
              fontFamily: AppType.serif,
              fontSize: size * .55,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
