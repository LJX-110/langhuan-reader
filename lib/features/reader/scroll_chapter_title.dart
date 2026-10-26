import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Opaque sticky chapter-title band for vertical scroll mode.
///
/// The list paints body-only tiles, so this overlay supplies the title that
/// page-turn mode bakes into each page.
class ScrollChapterTitle extends StatelessWidget {
  const ScrollChapterTitle({
    super.key,
    required this.chapter,
    required this.background,
    required this.color,
    required this.topInset,
    required this.bandHeight,
    this.horizontalPadding = 20,
    this.fontFamily,
  });

  final ValueListenable<String> chapter;
  final Color background;
  final Color color;

  /// Status-bar inset; the band starts below it like page-turn mode.
  final double topInset;

  /// Height of the title band itself.
  final double bandHeight;

  final double horizontalPadding;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return ColoredBox(
      color: background,
      child: SizedBox(
        height: topInset + bandHeight,
        child: Padding(
          padding: EdgeInsets.only(
            top: topInset,
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<String>(
              valueListenable: chapter,
              builder: (context, name, _) {
                return Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 / scale,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: .2,
                    color: color,
                    fontFamily: fontFamily,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
