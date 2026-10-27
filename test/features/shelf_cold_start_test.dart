import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyShelfModel extends ShelfModel {
  bool initCalled = false;

  @override
  Future<void> initShelf() async {
    initCalled = true;
  }
}

/// 2.1.0 regression: the shelf page replaced `books_widget.dart` but never
/// called `initShelf()`, so a cold start showed an empty shelf while the rows
/// were still in `reader.db`.
void main() {
  testWidgets('书架冷启动会调用 initShelf 读取本地书架', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();

    final spy = _SpyShelfModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shelfModelProvider.overrideWith((ref) => spy)],
        child: const MaterialApp(home: BookShelf()),
      ),
    );
    await tester.pump();

    expect(spy.initCalled, isTrue);
  });
}
