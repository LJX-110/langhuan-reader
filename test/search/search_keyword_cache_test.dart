import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/search/search_keyword_cache.dart';

SearchItem _item(String id) => SearchItem(id: id, name: '书$id');

void main() {
  group('SearchKeywordCache', () {
    test('round-trips hits and normalises the key', () {
      final cache = SearchKeywordCache();
      cache.put(' 斗破 苍穹 ', [_item('1')]);

      final hit = cache.get('斗破苍穹');

      expect(hit, isNotNull);
      expect(hit!.single.id, '1');
    });

    test('expired entries disappear', () async {
      final cache = SearchKeywordCache(ttl: const Duration(milliseconds: 1));
      cache.put('斗破', [_item('1')]);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cache.get('斗破'), isNull);
      expect(cache.length, 0);
    });

    test('caps the map and evicts the oldest keyword', () {
      final cache = SearchKeywordCache(maxEntries: 2);
      cache.put('一', [_item('1')]);
      cache.put('二', [_item('2')]);
      cache.put('三', [_item('3')]);

      expect(cache.get('一'), isNull);
      expect(cache.get('二'), isNotNull);
      expect(cache.get('三'), isNotNull);
      expect(cache.length, 2);
    });

    test('ignores empty keywords and empty result lists', () {
      final cache = SearchKeywordCache();
      cache.put('', [_item('1')]);
      cache.put('斗破', const []);
      cache.put('   ', [_item('2')]);

      expect(cache.length, 0);
    });

    test('returned lists are copies so callers cannot mutate the cache', () {
      final cache = SearchKeywordCache();
      cache.put('斗破', [_item('1')]);

      cache.get('斗破')!.add(_item('2'));

      expect(cache.get('斗破'), hasLength(1));
    });
  });
}
