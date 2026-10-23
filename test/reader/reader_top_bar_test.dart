import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/menu/reader_top_bar.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
  });

  testWidgets('scroll top bar follows the TOC index, not stale curPage', (
    tester,
  ) async {
    final model = ReadModel()..currentAnimationMode = 3;
    model.book = Book(
      id: 'book-1',
      name: '测试书',
      chapterIndex: 2,
      readingChapter: '第三章',
    );
    model.chapters = [
      ChapterTocEntry(title: '第一章', id: 'c1'),
      ChapterTocEntry(title: '第二章', id: 'c2'),
      ChapterTocEntry(title: '第三章', id: 'c3'),
    ];
    // Page-turn cache still describes the chapter we started from.
    model.curPage = ReadPage('', '第一章', 0, const []);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLanghuanTheme(dark: false),
        home: Scaffold(
          body: ReaderTopBar(
            readModel: model,
            chrome: const ReaderChrome(PaperTheme.white),
            onSearch: () {},
            bookmarked: false,
            onBookmark: () {},
            onExit: () {},
          ),
        ),
      ),
    );

    expect(find.text('第三章'), findsOneWidget);
    expect(find.text('第一章'), findsNothing);
  });
}
