import 'package:flutter/material.dart';

/// 全局唯一的 [ScaffoldMessenger]（挂在 `MaterialApp.scaffoldMessengerKey`），
/// 让没有 BuildContext 的模型/服务也能发反馈。
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 统一轻反馈（对齐文库 `showNovelFeedback`）：
/// 新消息替换旧消息，绝不叠层；可带一个动作（撤销 / 重试）。
///
/// 有 [context] 时优先用最近的 Scaffold，取不到则落回全局 messenger，
/// 因此界面销毁后（异步回调晚到）也不会崩。
///
/// 只 [ScaffoldMessengerState.hideCurrentSnackBar]（新替旧），
/// 绝不用 `clearSnackBars()`：它会连尚未展示、与本次操作无关的通知
/// 一起清掉（2026-11-06 修：移出书架通知"误删其他通知"的根因）。
void showFeedback(
  String message, {
  BuildContext? context,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger =
      (context == null ? null : ScaffoldMessenger.maybeOf(context)) ??
      rootMessengerKey.currentState;
  if (messenger == null) return;
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

/// 错误反馈：与轻反馈同一条通道，停留更久。
///
/// 文案只写「发生了什么 + 用户能做什么」；异常细节先过 [Redact.userMessage]，
/// 不直出异常对象、完整 URL 或堆栈（这些只进日志）。
void showError(
  String message, {
  BuildContext? context,
  String? actionLabel,
  VoidCallback? onAction,
}) => showFeedback(
  message,
  context: context,
  actionLabel: actionLabel,
  onAction: onAction,
  duration: const Duration(seconds: 4),
);
