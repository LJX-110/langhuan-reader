import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/features/reader/model/reader_content_reloader.dart';

void main() {
  group('ReaderContentReloader.reloadChapters', () {
    late Book book;
    late List<ChapterTocEntry> chapters;
    late List<String> events;

    ReaderContentReloader build({
      required Future<bool> Function({bool init}) loadToc,
      ChapterRepository? repo,
      void Function()? onRelayout,
    }) {
      return ReaderContentReloader(
        chaptersRepo: repo ?? ChapterRepository(),
        bookOf: () => book,
        chaptersOf: () => chapters,
        setChaptersLoading: (v) => events.add('loading:$v'),
        setLoadingHint: (v) => events.add('hint:$v'),
        loadToc: loadToc,
        fetchChapterBody: (id, {int? idx}) async => '',
        loadChapter: (idx) async =>
            ReadPage('', chapters[idx].title, 0, const []),
        setCurPage: (_) {},
        removeWarm: (_) {},
        clearPictures: () => events.add('clear'),
        openChapterAt: (idx, jump, {bool showLoading = true}) async {
          events.add('open:$idx:$jump:$showLoading');
          book.chapterIndex = idx;
        },
        restorePageIndex: (idx) => events.add('restore:$idx'),
        toggleMenu: () {},
        showLoading: (text) async {},
        hideLoading: () {},
        markNeedsPaint: () => events.add('paint'),
        notify: () => events.add('notify'),
        onRelayout: onRelayout,
      );
    }

    setUp(() {
      book = Book(id: 'b1', chapterIndex: 1, pageIndex: 3);
      chapters = [
        ChapterTocEntry(id: 'c1', title: '第一章', url: 'u1'),
        ChapterTocEntry(id: 'c2', title: '第二章', url: 'u2'),
      ];
      events = [];
    });

    test('keeps the same chapter when its TOC index moves', () async {
      final reloader = build(
        loadToc: ({bool init = false}) async {
          chapters = [
            ChapterTocEntry(id: 'c0', title: '序章', url: 'u0'),
            ChapterTocEntry(id: 'c1', title: '第一章', url: 'u1'),
            ChapterTocEntry(id: 'c2', title: '第二章', url: 'u2-new'),
          ];
          return true;
        },
      );

      expect(await reloader.reloadChapters(), isTrue);
      expect(book.chapterIndex, 2);
      expect(book.readingChapter, '第二章');
      expect(events, contains('clear'));
      expect(events, contains('open:2:false:false'));
      expect(events, contains('restore:3'));
      expect(events, contains('paint'));
      expect(events.first, 'loading:true');
      expect(events, contains('loading:false'));
    });

    test('does not re-open when the TOC reload failed', () async {
      final reloader = build(loadToc: ({bool init = false}) async => false);

      expect(await reloader.reloadChapters(), isFalse);
      expect(book.chapterIndex, 1);
      expect(events.where((e) => e.startsWith('open:')), isEmpty);
      expect(events.where((e) => e == 'clear'), isEmpty);
    });

    test('clamps to the old index when the chapter disappeared', () async {
      final reloader = build(
        loadToc: ({bool init = false}) async {
          chapters = [ChapterTocEntry(id: 'c0', title: '序章', url: 'u0')];
          return true;
        },
      );

      expect(await reloader.reloadChapters(), isTrue);
      expect(book.chapterIndex, 0);
      expect(events, contains('open:0:false:false'));
    });

    test('relayout reports a content change for scroll mode', () async {
      var relayouts = 0;
      final reloader = build(
        loadToc: ({bool init = false}) async => true,
        repo: _FakeChapterRepository(),
        onRelayout: () => relayouts++,
      );

      await reloader.relayoutPages();

      expect(relayouts, 1);
      expect(events, contains('open:1:false:false'));
      expect(events, contains('restore:3'));
    });
  });
}

class _FakeChapterRepository extends ChapterRepository {
  @override
  Future<int> clearAllPageLayouts({
    String? keepLayoutFp,
    String? bookId,
  }) async => 0;
}
