import 'package:flutter/material.dart';

/// 统一加载指示 —— 全应用唯一允许出现进度指示器的地方。
///
/// 页面里不再各自写 `CircularProgressIndicator` / `LinearProgressIndicator`：
/// - [LoadingView]：块内转圈，可带一行文案；
/// - [LoadingView.inline]：按钮 / 行内小转圈；
/// - [LoadingView.page]：整页 / 整块居中转圈；
/// - [LoadingBar]：线性进度（下载 / 导入）。
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.label,
    this.size = 22,
    this.strokeWidth = 2.4,
    this.color,
    this.centered = false,
    this.gap = 10,
  });

  /// 按钮 / 行内小转圈。
  const LoadingView.inline({super.key, this.color})
    : label = null,
      size = 16,
      strokeWidth = 2,
      centered = false,
      gap = 0;

  /// 整页 / 整块居中转圈。
  const LoadingView.page({super.key, this.label, this.color})
    : size = 28,
      strokeWidth = 2.6,
      centered = true,
      gap = 12;

  final String? label;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool centered;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
    final body = label == null
        ? spinner
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinner,
              SizedBox(height: gap),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ],
          );
    return centered ? Center(child: body) : body;
  }
}

/// 线性进度（下载 / 导入等确定或不确定进度）。
class LoadingBar extends StatelessWidget {
  const LoadingBar({
    super.key,
    this.value,
    this.minHeight = 4,
    this.color,
    this.backgroundColor,
  });

  final double? value;
  final double minHeight;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: minHeight,
    color: color,
    backgroundColor: backgroundColor,
  );
}
