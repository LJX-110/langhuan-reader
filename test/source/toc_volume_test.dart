import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/reader/model/toc_service.dart';
import 'package:langhuan/features/sources/model/search_book.dart';

/// 卷标题进入目录映射后只能成为分组元数据，绝不成为可读章节。
///
/// （原「引擎 TOC 解析」组随去双引擎删除：目录解析已由阅读内核承担。）
void main() {
  group('TocService.mapChapters', () {
    final book = Book(id: 'b1');

    test('attaches volumes, drops volume rows and url-less chapters', () {
      final entries = TocService.mapChapters(book, [
        SourceChapter(
          name: '- 第一卷 少年游 -',
          url: '',
          isVolume: true,
          index: 0,
        ),
        SourceChapter(
          name: '第一章 初入江湖',
          url: 'https://ex.com/1',
          index: 1,
        ),
        SourceChapter(
          name: '第二章',
          url: 'https://ex.com/2',
          index: 2,
        ),
        SourceChapter(name: '没有链接的章', url: '', index: 3),
        SourceChapter(
          name: '第二卷 风起',
          url: '',
          isVolume: true,
          index: 4,
        ),
        SourceChapter(
          name: '第三章',
          url: 'https://ex.com/3',
          index: 5,
        ),
      ]);

      expect(entries, hasLength(3));
      expect(entries.map((e) => e.ord).toList(), [0, 1, 2]);
      expect(entries[0].title, '第一章 初入江湖');
      expect(entries[0].volumeTitle, '第一卷 少年游');
      expect(entries[0].volumeOrd, 0);
      expect(entries[1].volumeTitle, '第一卷 少年游');
      expect(entries[2].volumeTitle, '第二卷 风起');
      expect(entries[2].volumeOrd, 1);
      expect(entries[2].url, 'https://ex.com/3');
    });

    test('sources without volumes keep empty grouping values', () {
      final entries = TocService.mapChapters(book, [
        SourceChapter(name: '第一章', url: 'https://ex.com/1', index: 0),
        SourceChapter(name: '第二章', url: 'https://ex.com/2', index: 1),
      ]);

      expect(entries, hasLength(2));
      expect(entries.every((e) => e.volumeTitle.isEmpty), isTrue);
      expect(entries.every((e) => e.volumeOrd == -1), isTrue);
    });
  });
}
