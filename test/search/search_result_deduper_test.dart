import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/search/search_result_deduper.dart';

SearchItem _item(String id) => SearchItem(id: id, name: id);

void main() {
  group('SearchResultDeduper', () {
    test('counts only ids that were not seen before', () {
      final deduper = SearchResultDeduper();
      final target = <SearchItem>[];

      expect(deduper.addAll([_item('a'), _item('b')], target), 2);
      expect(target, hasLength(2));

      // A source that ignores {{page}} returns the same page forever.
      expect(deduper.addAll([_item('a'), _item('b')], target), 0);
      expect(target, hasLength(2));

      expect(deduper.addAll([_item('a'), _item('c')], target), 1);
      expect(target.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('clear allows a fresh search to accept the same ids again', () {
      final deduper = SearchResultDeduper();
      final target = <SearchItem>[];

      deduper.addAll([_item('a')], target);
      deduper.clear();

      expect(deduper.addAll([_item('a')], target), 1);
      expect(target, hasLength(2));
    });
  });
}
