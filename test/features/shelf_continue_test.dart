import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 书架顶部「继续阅读」卡片：有进度的书才出现，点它续读最近在读的一本。
class _SpyShelfModel extends ShelfModel {
  /// 书架内容直接放进模型：`initShelf()` 在 initState 里同步跑完，
  /// 若此时 notifyListeners 会撞上"build 期间改 provider"的断言。
  _SpyShelfModel(List<Book> books) {
    shelf = books;
  }

  @override
  Future<void> initShelf() async {}
}

Future<void> _pumpShelf(WidgetTester tester, List<Book> books) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await SpUtil.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shelfModelProvider.overrideWith((ref) => _SpyShelfModel(books)),
      ],
      child: const MaterialApp(home: BookShelf()),
    ),
  );
  // 3D 书架有入场动画，用固定时长推进，避免 pumpAndSettle 等动画。
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('有进度的书显示「继续阅读」并带上书名与章节', (tester) async {
    final book = Book(
      id: 'b1',
      name: '测试书',
      sourceUrl: 'https://s.example',
      bookUrl: 'https://s.example/1',
      readingChapter: '第三章 风起',
      chapterIndex: 2,
      pageIndex: 1,
    );
    await _pumpShelf(tester, [book]);

    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('测试书'), findsWidgets);
    expect(find.text('第三章 风起'), findsOneWidget);
  });

  testWidgets('没进度的书不显示「继续阅读」', (tester) async {
    final book = Book(
      id: 'b2',
      name: '没读过',
      sourceUrl: 'https://s.example',
      bookUrl: 'https://s.example/2',
    );
    await _pumpShelf(tester, [book]);

    expect(find.text('继续阅读'), findsNothing);
  });
}
