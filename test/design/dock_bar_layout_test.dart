import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/app/shell/dock_bar.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// 2.3.0+14 regression: bottomNavigationBar 槽位里包了裸 Center，
/// 有界约束下 Center 会撑满全高 → body 被挤成 0 高 → 整机「只剩一个底栏」。
/// 修复 = Center(heightFactor: 1)（见 DockBar）。本测试锁定两条契约：
/// 1) 底栏高度 = 胶囊高度（+ 底部最小安全距），绝不能是整屏；
/// 2) body 保留完整高度。
void main() {
  testWidgets('DockBar：底栏只占胶囊高度，body 不被挤没', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLanghuanTheme(dark: false),
        home: Scaffold(
          body: const ColoredBox(
            color: Color(0xFF00FF00),
            child: SizedBox.expand(key: ValueKey('shell-body')),
          ),
          bottomNavigationBar: DockBar(index: 0, onTap: (_) {}),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final dockRect = tester.getRect(find.byType(LanhuanDock));
    expect(dockRect.height, LanhuanDock.dockHeight); // 54
    expect(dockRect.bottom, closeTo(800 - 10, 1)); // 贴底 + 最小 10 留白
    expect(dockRect.center.dx, closeTo(200, 1)); // 水平居中

    // body = 800 - (54 + 10) = 736；事故时这里是 0。
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-body'))).height,
      closeTo(736, 2),
    );
  });
}
