import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Sticky chapter band for vertical scroll mode.
///
/// 章节头与分页模式统一（对齐阅读）：
/// - 章首（顶部可见页 = 该章第 0 页）：大标题（17sp）+ 字数/更新时间小字，
///   与分页模式第 0 页的头部一致；
/// - 章中：弱化吸顶行头（14sp）；[hideRunning]（专注模式）不显示行头。
///
/// The list paints body-only tiles, so this overlay supplies the head that
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
    this.info,
    this.full,
    this.hideRunning = false,
    this.titleColor,
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

  /// 章首小字（字数/更新时间），随 [full] 一起使用。
  final ValueListenable<String>? info;

  /// 当前是否处于章首（顶部可见页为第 0 页）。
  final ValueListenable<bool>? full;

  /// 专注模式：非章首时不显示行头。
  final bool hideRunning;

  /// 章首大标题颜色（缺省沿用 [color]）。
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final fullNotifier = full;
    if (fullNotifier == null) {
      // Legacy path (tests / callers without head state): running head only.
      return _band(_runningHead(context));
    }
    return ValueListenableBuilder<bool>(
      valueListenable: fullNotifier,
      builder: (context, isFull, _) {
        if (isFull) return _band(_chapterHead(context));
        if (hideRunning) return const SizedBox.shrink();
        return _band(_runningHead(context));
      },
    );
  }

  Widget _band(Widget child) {
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
          child: child,
        ),
      ),
    );
  }

  /// 章首大标题 + 小字，与分页模式第 0 页的头部版式一致。
  Widget _chapterHead(BuildContext context) {
    final infoNotifier = info;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return ValueListenableBuilder<String>(
      valueListenable: chapter,
      builder: (context, name, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17 / scale,
                fontWeight: ReadSetting.titleFontWeight,
                height: 1.25,
                color: titleColor ?? color,
                fontFamily: fontFamily,
              ),
            ),
            if (infoNotifier != null)
              ValueListenableBuilder<String>(
                valueListenable: infoNotifier,
                builder: (context, meta, _) {
                  if (meta.isEmpty) return const SizedBox.shrink();
                  return Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11 / scale,
                      height: 1.2,
                      color: color,
                      fontFamily: fontFamily,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _runningHead(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return Align(
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
              fontWeight: ReadSetting.runningHeadFontWeight,
              height: 1.2,
              letterSpacing: .2,
              color: color,
              fontFamily: fontFamily,
            ),
          );
        },
      ),
    );
  }
}
