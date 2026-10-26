import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/import/source_validation.dart';

SourceParseResult _parse(List<Map<String, dynamic>> sources) =>
    SourceImporter.parseJson(jsonEncode(sources));

Map<String, dynamic> _source({
  String url = 'https://ex.com',
  String name = '测试源',
  String searchUrl = 'https://ex.com/search?q={{key}}',
  String exploreUrl = '',
  Map<String, dynamic>? ruleSearch,
}) => {
  'bookSourceUrl': url,
  'bookSourceName': name,
  'searchUrl': searchUrl,
  'exploreUrl': exploreUrl,
  'ruleSearch': ruleSearch ?? {'bookList': '.item', 'name': 'a@text'},
};

void main() {
  group('SourceValidator', () {
    test('accepts a structurally complete source', () {
      final report = SourceValidator.validate(_parse([_source()]));

      expect(report.total, 1);
      expect(report.invalid, isEmpty);
      expect(report.valid, hasLength(1));
    });

    test('rejects a missing bookSourceUrl', () {
      final report = SourceValidator.validate(
        _parse([_source(url: '', name: '无地址')]),
      );

      expect(report.valid, isEmpty);
      expect(report.invalid.single.problem, contains('bookSourceUrl'));
      expect(report.invalid.single.displayName, '无地址');
    });

    test('rejects a missing name', () {
      final report = SourceValidator.validate(_parse([_source(name: '')]));

      expect(report.invalid.single.problem, contains('书源名称'));
    });

    test('rejects a source without search or explore url', () {
      final report = SourceValidator.validate(
        _parse([_source(searchUrl: '', exploreUrl: '')]),
      );

      expect(report.invalid.single.problem, contains('搜索或发现地址'));
    });

    test('rejects a source whose rule sets are all empty', () {
      final report = SourceValidator.validate(
        _parse([
          _source(ruleSearch: const {}),
        ]),
      );

      expect(report.invalid.single.problem, contains('没有任何解析规则'));
    });

    test('rejects a search source without bookList', () {
      final report = SourceValidator.validate(
        _parse([
          _source(ruleSearch: {'name': 'a@text'}),
        ]),
      );

      expect(report.invalid.single.problem, contains('bookList'));
    });

    test('accepts an explore-only source with an explore list rule', () {
      final report = SourceValidator.validate(
        _parse([
          _source(
            searchUrl: '',
            exploreUrl: 'https://ex.com/list/{{page}}',
            ruleSearch: const {},
          )..['ruleExplore'] = {'bookList': '.item', 'name': 'a@text'},
        ]),
      );

      expect(report.valid, hasLength(1));
    });

    test('splits a mixed batch into valid and invalid', () {
      final report = SourceValidator.validate(
        _parse([
          _source(name: '好的'),
          _source(
            url: 'https://bad.example',
            name: '坏的',
            searchUrl: '',
            exploreUrl: '',
          ),
        ]),
      );

      expect(report.total, 2);
      expect(report.valid, hasLength(1));
      expect(report.invalid, hasLength(1));
    });
  });
}
