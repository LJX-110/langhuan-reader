import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/import/source_import_conflict.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

BookSource _source(
  String url, {
  String name = '测试源',
  String bookList = '.book',
  bool enabled = true,
  int customOrder = 0,
  int lastUpdateTime = 0,
  int respondTime = 0,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    enabled: enabled,
    customOrder: customOrder,
    lastUpdateTime: lastUpdateTime,
    respondTime: respondTime,
    ruleSearch: SearchRule(bookList: bookList),
  );
}

void main() {
  group('sourceRulesEqual', () {
    test('ignores local-only state such as enable, order and health', () {
      final local = _source(
        'https://a.example',
        enabled: false,
        customOrder: 9,
        lastUpdateTime: 1,
        respondTime: -1,
      );
      final incoming = _source(
        'https://a.example',
        enabled: true,
        customOrder: 0,
        lastUpdateTime: 2,
        respondTime: 120,
      );
      expect(sourceRulesEqual(local, incoming), isTrue);
    });

    test('detects changed reading rules', () {
      expect(
        sourceRulesEqual(
          _source('https://a.example', bookList: '.old'),
          _source('https://a.example', bookList: '.new'),
        ),
        isFalse,
      );
      expect(
        sourceRulesEqual(
          _source('https://a.example', name: '旧名'),
          _source('https://a.example', name: '新名'),
        ),
        isFalse,
      );
    });
  });

  group('buildSourceImportConflict', () {
    test('separates new, changed and unchanged sources', () {
      final conflict = buildSourceImportConflict(
        incoming: [
          _source('https://new.example'),
          _source('https://changed.example', bookList: '.new'),
          _source('https://same.example'),
        ],
        existing: [
          _source('https://changed.example', bookList: '.old'),
          _source('https://same.example', customOrder: 4),
        ],
      );

      expect(conflict.newCount, 1);
      expect(conflict.changedCount, 1);
      expect(conflict.unchangedCount, 1);
      expect(conflict.existingCount, 2);
      expect(conflict.hasChanged, isTrue);
      expect(conflict.changedUrls, {'https://changed.example'});
      expect(conflict.unchangedUrls, {'https://same.example'});
    });

    test('counts duplicate incoming urls once and ignores empty urls', () {
      final conflict = buildSourceImportConflict(
        incoming: [
          _source(''),
          _source('https://a.example'),
          _source('https://a.example', bookList: '.ignored-duplicate'),
        ],
        existing: const [],
      );
      expect(conflict.newCount, 1);
      expect(conflict.changedCount, 0);
      expect(conflict.unchangedCount, 0);
    });

    test('reports no changes when every existing rule matches', () {
      final conflict = buildSourceImportConflict(
        incoming: [_source('https://same.example')],
        existing: [_source('https://same.example', enabled: false)],
      );
      expect(conflict.hasChanged, isFalse);
      expect(conflict.newCount, 0);
      expect(conflict.unchangedCount, 1);
    });
  });

  group('SourceImportConflict.withoutUnchanged', () {
    test('keeps new and changed rows but drops identical rules', () {
      final conflict = buildSourceImportConflict(
        incoming: [
          _source('https://new.example'),
          _source('https://changed.example', bookList: '.new'),
          _source('https://same.example'),
        ],
        existing: [
          _source('https://changed.example', bookList: '.old'),
          _source('https://same.example'),
        ],
      );
      final filtered = conflict.withoutUnchanged(
        SourceParseResult(
          sources: [
            _source('https://new.example'),
            _source('https://changed.example', bookList: '.new'),
            _source('https://same.example'),
          ],
          skipped: 2,
          duplicatesInBatch: 1,
        ),
      );

      expect(filtered.sources.map((s) => s.bookSourceUrl), [
        'https://new.example',
        'https://changed.example',
      ]);
      expect(filtered.skipped, 2);
      expect(filtered.duplicatesInBatch, 1);
    });
  });
}
