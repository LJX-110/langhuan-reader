import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/search/search_result_ranker.dart';

SearchItem _item(String name, {String author = '', String id = ''}) =>
    SearchItem(id: id.isEmpty ? name : id, name: name, author: author);

void main() {
  group('SearchResultRanker', () {
    test('orders exact > prefix > contains > author > rest', () {
      final items = [
        _item('别的书', author: '斗破苍穹作者'), // author match
        _item('斗破苍穹外传'), // prefix
        _item('斗破苍穹'), // exact
        _item('我读斗破苍穹的日子'), // contains
        _item('无关'), // rest
      ];

      final ranked = SearchResultRanker.rank(items, '斗破苍穹');

      expect(ranked.map((e) => e.name).toList(), [
        '斗破苍穹',
        '斗破苍穹外传',
        '我读斗破苍穹的日子',
        '别的书',
        '无关',
      ]);
    });

    test('is stable inside a rank (arrival order kept)', () {
      final items = [
        _item('斗破苍穹', id: 'a'),
        _item('斗破苍穹', id: 'b'),
        _item('斗破苍穹', id: 'c'),
      ];

      final ranked = SearchResultRanker.rank(items, '斗破苍穹');

      expect(ranked.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('ignores whitespace and case differences', () {
      final items = [_item('DOU 破'), _item('斗破')];

      final ranked = SearchResultRanker.rank(items, '斗 破');

      expect(ranked.first.name, '斗破');
    });

    test('returns the original list for an empty keyword', () {
      final items = [_item('甲'), _item('乙')];
      expect(identical(SearchResultRanker.rank(items, '  '), items), isTrue);
    });
  });
}
