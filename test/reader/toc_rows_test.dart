import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/reader/model/toc_rows.dart';

ChapterTocEntry _chapter(
  String title, {
  String volume = '',
  int volumeOrd = -1,
}) => ChapterTocEntry(
  id: title,
  title: title,
  url: 'https://ex.com/$title',
  volumeTitle: volume,
  volumeOrd: volumeOrd,
);

void main() {
  group('buildTocRows', () {
    test('sources without volumes render chapters only', () {
      final rows = buildTocRows([
        _chapter('第一章'),
        _chapter('第二章'),
      ]);

      expect(rows, hasLength(2));
      expect(rows.every((r) => !r.isVolume), isTrue);
      expect(rows.map((r) => r.chapterIndex).toList(), [0, 1]);
    });

    test('inserts a volume header once and counts its chapters', () {
      final rows = buildTocRows([
        _chapter('第一章', volume: '第一卷'),
        _chapter('第二章', volume: '第一卷'),
        _chapter('第三章', volume: '第二卷', volumeOrd: 1),
        _chapter('第四章'),
      ]);

      expect(rows.map((r) => r.isVolume).toList(), [
        true, false, false, true, false, false,
      ]);
      expect(rows[0].title, '第一卷');
      expect(rows[0].count, 2);
      expect(rows[3].title, '第二卷');
      expect(rows[3].count, 1);
      // Chapter indices never count the volume rows.
      expect(
        rows.where((r) => !r.isVolume).map((r) => r.chapterIndex).toList(),
        [0, 1, 2, 3],
      );
    });

    test('search matches chapter names and keeps the volume header once', () {
      final chapters = [
        _chapter('第一章 初入'),
        _chapter('第二章 山雨', volume: '第二卷', volumeOrd: 1),
        _chapter('第三章 风起', volume: '第二卷', volumeOrd: 1),
      ];

      final rows = buildTocRows(chapters, query: '风');

      expect(rows.map((r) => r.isVolume).toList(), [true, false]);
      expect(rows[0].title, '第二卷');
      expect(rows[1].chapterIndex, 2);
    });

    test('search matches a volume name and chapter numbers', () {
      final chapters = [
        _chapter('第一章', volume: '少年游'),
        _chapter('第二章', volume: '风起云涌', volumeOrd: 1),
      ];

      final byVolume = buildTocRows(chapters, query: '少年游');
      expect(byVolume, hasLength(2));
      expect(byVolume[0].isVolume, isTrue);
      expect(byVolume[1].chapterIndex, 0);

      final byNumber = buildTocRows(chapters, query: '2');
      expect(byNumber, hasLength(2));
      expect(byNumber[1].chapterIndex, 1);
    });
  });

  group('tocRowForChapter', () {
    test('maps chapter indices past the volume headers', () {
      final rows = buildTocRows([
        _chapter('第一章', volume: '第一卷'),
        _chapter('第二章'),
      ]);

      // rows: [volume, chapter0, chapter1]
      expect(tocRowForChapter(rows, 0), 1);
      expect(tocRowForChapter(rows, 1), 2);
    });

    test('falls back to the first row for unknown indices', () {
      final rows = buildTocRows([_chapter('第一章')]);
      expect(tocRowForChapter(rows, 99), 0);
      expect(tocRowForChapter(const [], 0), 0);
    });
  });
}
