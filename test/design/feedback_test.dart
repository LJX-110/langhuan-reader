import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/feedback.dart';

/// 统一轻反馈回归（D/F）：
/// - 新消息替换旧消息（不叠层）；
/// - 到期自动消失（不会挂在页面上）；
/// - 动作按钮可点。
///
/// 历史 bug：`showFeedback` 曾调用 `clearSnackBars()`，把尚未展示、
/// 与本次操作无关的通知一起清掉（"移出书架误删其他通知"根因）。
void main() {
  testWidgets('showFeedback：新替旧、按时自动消失、动作可点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.expand())),
    );
    final ctx = tester.element(find.byType(Scaffold));

    // 第一条出现。
    showFeedback(ctx, '第一条', duration: const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('第一条'), findsOneWidget);

    // 新替旧：第二条顶掉第一条，旧条入场动画结束后即退场。
    showFeedback(ctx, '第二条', duration: const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('第二条'), findsOneWidget);
    expect(find.text('第一条'), findsNothing);

    // 到期自动消失。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('第二条'), findsNothing);

    // 动作按钮可点。
    var undone = false;
    showFeedback(ctx, '已移除', actionLabel: '撤销', onAction: () => undone = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('已移除'), findsNothing);
  });
}
