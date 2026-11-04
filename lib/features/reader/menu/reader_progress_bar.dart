import 'package:flutter/material.dart';

import 'package:langhuan/design/motion.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';

/// 阅读器底栏进度条：显示全书进度，支持拖动 / 点按跳转。
///
/// 对齐 Wenku8 的手感：平时只显示 4px 细轨，拖动时显示滑块与
/// 「第 N 章 · X%」预览；36px 高的触摸区用 LayoutBuilder 换算比例
/// （localPosition 必须除以手势区同一宽度）。
class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.chrome,
    required this.value,
    required this.dragging,
    required this.previewText,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onPointerCancel,
  });

  final ReaderChrome chrome;
  final double value;
  final bool dragging;
  final String previewText;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  /// 底层指针取消：拖拽被父级抢走后可能不走 onDragCancel 直接进 onEnd，
  /// 父级在提交跳转前用该回调做检查。
  final VoidCallback onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOn(context, chrome.panelBg);
    final v = value.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 拖动时显示预览；高度常驻，避免出现 / 消失时布局跳动。
        SizedBox(
          height: 16,
          child: AnimatedOpacity(
            opacity: dragging ? 1 : 0,
            duration: AppMotion.contact,
            child: Text(
              previewText,
              style: TextStyle(fontSize: 12, color: chrome.muted),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            double toRatio(double dx) =>
                barWidth <= 0 ? 0.0 : (dx / barWidth).clamp(0.0, 1.0);
            return Listener(
              onPointerCancel: (_) => onPointerCancel(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => onDragStart(),
                onHorizontalDragUpdate: (details) =>
                    onDragUpdate(toRatio(details.localPosition.dx)),
                onHorizontalDragEnd: (_) => onDragEnd(),
                onHorizontalDragCancel: onDragCancel,
                onTapDown: (details) {
                  onDragStart();
                  onDragUpdate(toRatio(details.localPosition.dx));
                },
                onTapUp: (_) => onDragEnd(),
                onTapCancel: onDragCancel,
                child: SizedBox(
                  height: 36,
                  width: barWidth,
                  child: Center(
                    child: SizedBox(
                      height: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final maxThumbLeft = (w - 14) > 0 ? w - 14 : 0.0;
                          return Stack(
                            children: [
                              // 轨道
                              Container(
                                width: w,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: chrome.divider,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // 已读部分
                              Container(
                                width: w * v,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // 滑块（拖动时显示）
                              if (dragging)
                                Positioned(
                                  left: (w * v - 7).clamp(0.0, maxThumbLeft),
                                  top: -5,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 进度条的纯计算：数值 ↔ 目标章节 / 章内比例、预览文字。
///
/// 章节等权（本机只持有当前章的页数，不能像 Wenku8 那样全文按字数加权）；
/// 章内按 `pageIndex / (pages - 1)`，与 `openChapterAt + jumpToPage` 互逆。
class ReaderProgress {
  const ReaderProgress._();

  /// 全书进度（0~1）。
  static double valueOf({
    required int chapter,
    required int pageIndex,
    required int pages,
    required int total,
  }) {
    if (total <= 0) return 0;
    final ratio = pages > 1
        ? (pageIndex / (pages - 1)).clamp(0.0, 1.0)
        : 0.0;
    return ((chapter + ratio) / total).clamp(0.0, 1.0);
  }

  /// 进度值换算为目标章节与章内比例。
  static ({int chapter, double ratio}) targetOf(double value, int total) {
    if (total <= 0) return (chapter: 0, ratio: 0);
    final scaled = value.clamp(0.0, 1.0) * total;
    var chapter = scaled.floor();
    var ratio = scaled - chapter;
    if (chapter >= total) {
      chapter = total - 1;
      ratio = 1;
    }
    return (chapter: chapter, ratio: ratio);
  }

  /// 拖动预览文字：第 N 章 · X%。
  static String previewOf(double value, int total) {
    if (total <= 0) return '';
    final chapter = targetOf(value, total).chapter;
    return '第 ${chapter + 1} 章 · ${(value.clamp(0.0, 1.0) * 100).round()}%';
  }
}
