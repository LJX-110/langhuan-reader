import 'package:flutter/material.dart';

/// 统一轻反馈（对齐文库 `showNovelFeedback`）：
/// 新消息替换旧消息，避免 BotToast 叠层；可带一个动作（撤销 / 重试）。
///
/// 只 [ScaffoldMessengerState.hideCurrentSnackBar]（新替旧），
/// 绝不用 `clearSnackBars()`：它会连尚未展示、与本次操作无关的通知
/// 一起清掉（2026-11-06 修：移出书架通知"误删其他通知"的根因）。
void showFeedback(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}
