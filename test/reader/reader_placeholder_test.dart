import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/entities/text_line.dart';
import 'package:langhuan/data/entities/text_page.dart';
import 'package:langhuan/features/reader/model/chapter_window_controller.dart';
import 'package:langhuan/features/reader/model/reader_loading_presenter.dart';

const _chapterTitles = ['第一章', '第二章', '第三章', '第四章'];

ReadPage _realPage(String title, {int pageCount = 2}) {
  return ReadPage(
    '正文内容',
    title,
    0,
    List.generate(
      pageCount,
      (i) => TextPage([TextLine.simple('第 $i 页')], 20),
    ),
  );
}

class _Harness {
  _Harness({int chapterIndex = 1, int pageIndex = 3}) {
    book = Book(id: 'book-1', chapterIndex: chapterIndex, pageIndex: pageIndex);
    controller = ChapterWindowController(
      bookOf: () => book,
      chaptersLength: () => titles.length,
      loadChapter: (idx) => load(idx),
      warmDiskCaches: (idx) => warm(idx),
      messagePage: (title, message) async {
        final page = ReadPage(message, title, 0, [
          TextPage([TextLine.simple(message)], 20),
        ]);
        page.isPlaceholder = true;
        return page;
      },
      showLoading: (text) async {
        loadingHint = text;
      },
      hideLoading: () {},
      curPageOf: () => curPage,
      chapterTitleOf: (idx) =>
          idx >= 0 && idx < titles.length ? titles[idx] : '',
      onLoadFailed:
          (idx, title, error, {required bool keptContent}) {
            failedIndex = idx;
            failedTitle = title;
            failureKeptContent = keptContent;
          },
      onLoadSucceeded: () {
        loadError = null;
      },
      setCurPage: (page) => curPage = page,
      setPrePage: (page) => prePage = page,
      setNextPage: (page) => nextPage = page,
      clearPictures: () => picturesCleared++,
      warmPictures: () {},
      restorePageIndex: (idx) => book.pageIndex = idx,
      markNeedsPaint: () {},
      notify: () => notifyCount++,
    );
  }

  final titles = _chapterTitles;
  late final Book book;
  late final ChapterWindowController controller;

  ReadPage? curPage;
  ReadPage? prePage;
  ReadPage? nextPage;
  String? loadingHint;
  int? failedIndex;
  String? failedTitle;
  bool? failureKeptContent;
  String? loadError;
  int picturesCleared = 0;
  int notifyCount = 0;

  Future<ReadPage?> Function(int idx) load = (idx) async =>
      _realPage(_chapterTitles[idx]);
  Future<void> Function(int idx) warm = (idx) async {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadPage placeholder marker', () {
    test('is not serialized and old cache reads as false', () {
      final page = _realPage('第一章')..isPlaceholder = true;
      final json = page.toJson();

      expect(json.containsKey('isPlaceholder'), isFalse);

      // Legacy pages_json rows predate the marker and must stay readable.
      final legacy = ReadPage.fromJson({
        'chapterContent': '正文内容',
        'chapterName': '第一章',
        'height': 0,
        'pages': [
          {'lines': [], 'height': 20, 'pageIndex': 0},
        ],
      });
      expect(legacy.chapterName, '第一章');
      expect(legacy.isPlaceholder, isFalse);
    });

    test('syncPlaceholder keeps the exact chapter title', () {
      final page = ReaderLoadingPresenter.syncPlaceholder(
        '正在加载…',
        chapterTitle: '第三章',
      );
      expect(page.chapterName, '第三章');
      expect(page.isPlaceholder, isTrue);

      final blank = ReaderLoadingPresenter.syncPlaceholder('正在加载…');
      expect(blank.chapterName, isEmpty);
      expect(blank.isPlaceholder, isTrue);
    });
  });

  group('ChapterWindowController TOC jump', () {
    test('preview paints the target title without moving progress', () {
      final h = _Harness(chapterIndex: 1, pageIndex: 3);
      h.curPage = _realPage('第一章');

      h.controller.previewChapter(2);

      expect(h.curPage!.chapterName, '第三章');
      expect(h.curPage!.isPlaceholder, isTrue);
      expect(h.book.chapterIndex, 1);
      expect(h.book.pageIndex, 3);
      expect(h.picturesCleared, 1);
    });

    test('successful open replaces the placeholder with real content', () async {
      final h = _Harness();
      h.curPage = _realPage('第一章');
      h.controller.previewChapter(2);

      await h.controller.openAt(2, true, showLoadingUi: false);

      expect(h.curPage!.chapterName, '第三章');
      expect(h.curPage!.isPlaceholder, isFalse);
      expect(h.book.chapterIndex, 2);
      expect(h.book.pageIndex, 0);
      expect(h.failureKeptContent, isNull);
    });

    test('failed open restores the last readable page and progress', () async {
      final h = _Harness(chapterIndex: 1, pageIndex: 3);
      h.curPage = _realPage('第一章');
      h.load = (idx) async => throw StateError('network down');

      h.controller.previewChapter(2);
      await h.controller.openAt(2, true, showLoadingUi: false);

      expect(h.curPage!.chapterName, '第一章');
      expect(h.curPage!.isPlaceholder, isFalse);
      expect(h.book.chapterIndex, 1);
      expect(h.book.pageIndex, 3);
      expect(h.failedIndex, 2);
      expect(h.failedTitle, '第三章');
      expect(h.failureKeptContent, isTrue);
    });

    test('disk warm never blocks the chapter body', () async {
      final h = _Harness();
      final warmGate = Completer<void>();
      h.warm = (idx) => warmGate.future;
      h.load = (idx) async => _realPage('第二章');

      await h.controller
          .openAt(1, true, showLoadingUi: false)
          .timeout(const Duration(seconds: 1));

      expect(h.curPage!.chapterName, '第二章');
      expect(h.curPage!.isPlaceholder, isFalse);
      warmGate.complete();
    });
  });
}
