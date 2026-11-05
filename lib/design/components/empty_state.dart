import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// 空态对齐方式：[left] 左对齐大标题（首屏级空态）；[center] 居中紧凑版。
enum EmptyStateAlignment { center, left }

/// 唯一空态组件（批次 7·一致性）：标题 + 可选说明 + 可选动作。
///
/// 视觉对齐现役书架空态（本次抽取未改外观）：
/// - [EmptyStateAlignment.left]：24/80 边距、16sp 标题、6px 间距（书架首屏空态）；
/// - [EmptyStateAlignment.center]：居中、14sp 标题、8px 间距（筛选/列表空态）。
///
/// 用法约定（见 `docs/STANDARDS.md`）：页面空态一律走本组件，不再手写。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.hint,
    this.action,
    this.alignment = EmptyStateAlignment.center,
  });

  final String title;
  final String? hint;

  /// 动作区（通常是 TextButton）；间距由本组件统一给。
  final Widget? action;

  final EmptyStateAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final left = alignment == EmptyStateAlignment.left;
    final gap = left ? 6.0 : 8.0;

    final children = <Widget>[
      Text(
        title,
        style: TextStyle(
          color: primary,
          fontSize: left ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (hint != null && hint!.isNotEmpty) ...[
        SizedBox(height: gap),
        Text(hint!, style: TextStyle(color: muted, fontSize: 12)),
      ],
      if (action != null) ...[
        SizedBox(height: gap),
        action!,
      ],
    ];

    if (left) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
