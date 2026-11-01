import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/source_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 书源编辑器：字段回读、raw_json 重建、地址校验。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  /// 大视口一次渲染整个长表单，避免滚动定位；并装好 BotToast。
  Future<void> pumpEditor(
    WidgetTester tester, {
    required BookSource source,
    bool isNew = false,
    required Future<void> Function(BookSource source) onSave,
  }) async {
    tester.view.physicalSize = const Size(1000, 6400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: BotToastInit(),
          navigatorObservers: [BotToastNavigatorObserver()],
          home: SourceEditPage(source: source, isNew: isNew, onSave: onSave),
        ),
      ),
    );
  }

  BookSource sample() => BookSource(
    bookSourceUrl: 'https://ex.com',
    bookSourceName: '旧名',
    bookSourceGroup: '分组甲',
    searchUrl: 'https://ex.com/search?q={{key}}',
    ruleSearch: SearchRule(bookList: '.results a', name: 'h3@text'),
    ruleToc: TocRule(chapterList: '.old-toc'),
    ruleContent: ContentRule(content: '#content@html'),
    rawJson: '{"legacy":true}',
  );

  testWidgets('编辑保存：字段回读正确且 raw_json 重建', (tester) async {
    BookSource? saved;
    await pumpEditor(
      tester,
      source: sample(),
      onSave: (s) async => saved = s,
    );

    await tester.enterText(find.byKey(const ValueKey('edit-name')), '新名');
    await tester.enterText(
      find.byKey(const ValueKey('edit-t.chapterList')),
      '.new-toc',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-c.content')),
      '#new@text',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(saved, isNotNull);
    final s = saved!;
    expect(s.bookSourceName, '新名');
    expect(s.bookSourceUrl, 'https://ex.com');
    expect(s.bookSourceGroup, '分组甲');
    expect(s.searchUrl, 'https://ex.com/search?q={{key}}');
    expect(s.ruleSearch.bookList, '.results a');
    expect(s.ruleSearch.name, 'h3@text');
    expect(s.ruleToc.chapterList, '.new-toc');
    expect(s.ruleContent.content, '#new@text');
    // 规则已改：raw_json 必须重建，导出不能带旧内容。
    expect(s.rawJson, isEmpty);
  });

  testWidgets('新建：地址非法时拒绝保存，合法后放行', (tester) async {
    var saveCalls = 0;
    await pumpEditor(
      tester,
      source: BookSource(),
      isNew: true,
      onSave: (_) async => saveCalls++,
    );

    await tester.enterText(find.byKey(const ValueKey('edit-url')), 'ex.com');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(seconds: 3)); // 冲掉提示的计时器
    expect(saveCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('edit-url')),
      'https://ex.com',
    );
    await tester.enterText(find.byKey(const ValueKey('edit-name')), '新源');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(saveCalls, 1);
  });
}
