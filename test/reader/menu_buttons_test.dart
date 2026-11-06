import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chapter_panel.dart';
import 'package:langhuan/features/reader/menu/reader_settings_panel.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/reader_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读页菜单按钮回归（B 项）：
/// - 章步进按钮单次点击只推进一章（不重复触发）；
/// - 设置面板可开可收（按钮可点、面板可切）；
/// - 「目录」只发一次 OpenChapters 并收起菜单。
class _SpyModel extends ReadModel {
  int opened = 0;

  @override
  Future<void> openChapterAt(
    int idx,
    bool jump, {
    bool showLoading = true,
  }) async {
    opened++;
    book?.chapterIndex = idx;
    notifyListeners();
  }

  @override
  void scheduleProgressSave({Duration delay = Duration.zero}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  testWidgets('菜单按钮可点、面板可切、目录单次触发、步进不重复', (tester) async {
    final model = _SpyModel()
      ..showMenu = true
      ..chapters = [
        ChapterTocEntry(id: 'c1', title: '第一章', url: 'https://ex.com/1'),
        ChapterTocEntry(id: 'c2', title: '第二章', url: 'https://ex.com/2'),
        ChapterTocEntry(id: 'c3', title: '第三章', url: 'https://ex.com/3'),
      ];
    model.book = Book(
      id: 'b1',
      name: '测试书',
      chapterIndex: 1,
      readingChapter: '第二章',
    );
    model.curPage = ReadPage('', '第二章', 0, const []);

    final events = <OpenChapters>[];
    final sub = eventBus.on<OpenChapters>().listen(events.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [readModelProvider.overrideWith((ref) => model)],
        child: MaterialApp(
          theme: buildLanghuanTheme(dark: false),
          home: Scaffold(body: ReaderMenu(onExit: () {})),
        ),
      ),
    );
    await tester.pump();

    // 章步进：点一次只开一章。
    await tester.tap(find.text('下一章'));
    await tester.pump();
    expect(model.opened, 1);
    expect(model.book?.chapterIndex, 2);
    await tester.tap(find.text('上一章'));
    await tester.pump();
    expect(model.opened, 2);
    expect(model.book?.chapterIndex, 1);

    // 设置面板：开（先切帧启动动画，再补时长走完）。
    await tester.tap(find.text('设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.byType(ReaderSettingsPanel), findsOneWidget);

    // 设置面板：收（多补一帧：退场完成后 AnimatedSwitcher 才移除旧面板）。
    await tester.tap(find.text('设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    expect(find.byType(ReaderSettingsPanel), findsNothing);
    expect(find.byType(ReaderChapterPanel), findsOneWidget);

    // 目录：收起菜单 + 只发一次事件。
    await tester.tap(find.text('目录'));
    await tester.pump();
    expect(events.length, 1);
    expect(model.showMenu, isFalse);
  });
}
