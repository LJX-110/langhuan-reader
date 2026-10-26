import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/source_groups.dart';

BookSource _source(String name, String group) =>
    BookSource(bookSourceUrl: 'https://$name', bookSourceName: name)
      ..bookSourceGroup = group;

void main() {
  group('SourceGroups.parse', () {
    test('splits on comma variants, trims and dedupes', () {
      expect(SourceGroups.parse('小说, 备用'), ['小说', '备用']);
      expect(SourceGroups.parse('小说，备用；其它'), ['小说', '备用', '其它']);
      expect(SourceGroups.parse('小说, 小说'), ['小说']);
      expect(SourceGroups.parse('  ,  '), isEmpty);
      expect(SourceGroups.parse(''), isEmpty);
    });
  });

  group('SourceGroups.collect', () {
    test('keeps first-appearance order across sources', () {
      final groups = SourceGroups.collect([
        _source('a', '小说'),
        _source('b', '备用,小说'),
        _source('c', ''),
        _source('d', '出版'),
      ]);

      expect(groups, ['小说', '备用', '出版']);
    });
  });

  group('SourceGroups.filter', () {
    final sources = [
      _source('a', '小说'),
      _source('b', '备用'),
      _source('c', '小说,备用'),
      _source('d', ''),
    ];

    test('an empty group means everything', () {
      expect(SourceGroups.filter(sources, ''), hasLength(4));
    });

    test('filters by membership, including multi-group sources', () {
      expect(
        SourceGroups.filter(sources, '小说').map((s) => s.bookSourceName),
        ['a', 'c'],
      );
      expect(
        SourceGroups.filter(sources, '备用').map((s) => s.bookSourceName),
        ['b', 'c'],
      );
      expect(SourceGroups.filter(sources, '不存在'), isEmpty);
    });
  });
}
