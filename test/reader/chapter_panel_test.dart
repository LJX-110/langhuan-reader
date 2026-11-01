import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/reader/chapter_view.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 目录面板：有界高度（约 64%）、当前章高亮、数字搜索精确直跳。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  testWidgets('目录面板：有界高度、当前章高亮、数字搜索过滤', (tester) async {
    final model = ReadModel()
      ..chapters = [
        ChapterTocEntry(id: 'c1', title: '第一章', url: 'https://ex.com/1'),
        ChapterTocEntry(id: 'c2', title: '第二章', url: 'https://ex.com/2'),
        ChapterTocEntry(id: 'c3', title: '第三章', url: 'https://ex.com/3'),
      ];
    model.book = Book(id: 'b1', name: '测试书', chapterIndex: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [readModelProvider.overrideWith((ref) => model)],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: const ChapterView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 有界面板：高度约 64%，不是全屏页。
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final panel = tester.getSize(find.byType(ChapterView));
    expect(panel.height, lessThan(screen * 0.7));
    expect(panel.height, greaterThan(200));

    // 全书计数与当前章。
    expect(find.text('共 3 章 · 当前第 2 章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);

    // 数字搜索 = 精确章序：只剩「第三章」。
    await tester.tap(find.byTooltip('搜索章节'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '3');
    await tester.pump();
    expect(find.text('第三章'), findsOneWidget);
    expect(find.text('第一章'), findsNothing);
    expect(find.text('第二章'), findsNothing);
  });
}
