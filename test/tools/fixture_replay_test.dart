import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';

/// 离线回放：把 `test/fixtures/live/*.json` 里的真实页面过一遍书源规则，
/// 不联网、不依赖 JS 运行时。样本格式见同目录 README。
void main() {
  final dir = Directory('test/fixtures/live');
  final files = dir.existsSync()
      ? (dir.listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.json'))
              .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  group('live fixture replay', () {
    for (final file in files) {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = (raw['name'] ?? file.uri.pathSegments.last).toString();
      test(name, () {
        final source = BookSource.fromLegadoJson(
          Map<String, dynamic>.from(raw['source'] as Map),
        );
        final baseUrl = (raw['baseUrl'] ?? source.bookSourceUrl).toString();
        final body = raw['bodyFile'] != null
            ? File('${dir.path}/${raw['bodyFile']}').readAsStringSync()
            : (raw['body'] ?? '').toString();
        expect(body, isNotEmpty, reason: 'fixture 里没有 body / bodyFile');

        final kind = (raw['kind'] ?? 'search').toString();
        expect(kind, 'search', reason: '目前只实现了 search 回放');

        final rule = AnalyzeRule(
          content: body,
          baseUrl: baseUrl,
          isJson: raw['isJson'] == true,
          jsLib: source.jsLib,
        );
        final items = rule.getList(source.ruleSearch.bookList);
        final expect_ = Map<String, dynamic>.from(raw['expect'] ?? const {});
        if (expect_['listCount'] != null) {
          expect(items.length, expect_['listCount'], reason: '列表条数不符');
        }

        final names = <String>[];
        final urls = <String>[];
        for (final item in items) {
          final n = rule.getString(source.ruleSearch.name, scope: item).trim();
          final u = rule.getString(source.ruleSearch.bookUrl, scope: item).trim();
          if (n.isNotEmpty) names.add(n);
          if (u.isNotEmpty) urls.add(u);
        }
        for (final want in (expect_['names'] as List? ?? const [])) {
          expect(names, contains(want.toString()), reason: '书名没取到');
        }
        for (final want in (expect_['urls'] as List? ?? const [])) {
          expect(urls, contains(want.toString()), reason: 'bookUrl 没取到');
        }
      });
    }
  }, skip: files.isEmpty ? 'test/fixtures/live/ 里还没有样本' : false);
}
