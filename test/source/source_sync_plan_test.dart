import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/sync/source_sync_plan.dart';

void main() {
  group('buildSourceSyncPlan', () {
    test('separates incoming urls into new and existing', () {
      final plan = buildSourceSyncPlan(
        incomingUrls: ['a', 'b', 'c', 'a'],
        existingUrls: {'b'},
      );
      expect(plan.newCount, 2);
      expect(plan.existingCount, 1);
      expect(plan.hasExisting, isTrue);
      expect(plan.total, 3);
    });

    test('ignores empty and duplicate urls', () {
      final plan = buildSourceSyncPlan(
        incomingUrls: ['', 'a', 'a', ''],
        existingUrls: const {},
      );
      expect(plan.newCount, 1);
      expect(plan.existingCount, 0);
      expect(plan.hasExisting, isFalse);
    });
  });

  group('groupDuplicateLocalSources', () {
    test('groups local sources with the same name and ignores remote ones', () {
      final sources = [
        BookSource(bookSourceUrl: 'local://hash-1', bookSourceName: '同一本'),
        BookSource(bookSourceUrl: 'local://hash-2', bookSourceName: '同一本'),
        BookSource(bookSourceUrl: 'local://hash-3', bookSourceName: '另一本'),
        BookSource(bookSourceUrl: 'https://example.com', bookSourceName: '同一本'),
      ];

      final groups = groupDuplicateLocalSources(sources);

      expect(groups, hasLength(1));
      expect(groups.single, hasLength(2));
      expect(
        groups.single.map((source) => source.bookSourceUrl),
        containsAll(['local://hash-1', 'local://hash-2']),
      );
    });
  });
}
