import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';

/// Opt-in live debug for one source's detail-page rules.
///
///   $env:LANGHUAN_DEBUG_PACK='..\备份\2026-10-28\pack_diag.json'
///   $env:LANGHUAN_DEBUG_SOURCE='中文万维'
///   flutter test test/tools/detail_live_debug_test.dart
void main() {
  final packPath = Platform.environment['LANGHUAN_DEBUG_PACK'] ?? '';
  final sourceName = Platform.environment['LANGHUAN_DEBUG_SOURCE'] ?? '';

  test('detail rule debug', () async {
    final parsed = SourceImporter.parseJson(File(packPath).readAsStringSync());
    final source = parsed.sources.firstWhere(
      (s) => s.bookSourceName == sourceName,
    );
    final engine = BookSourceEngine();
    final search = await engine.searchWithReport(source, '斗破苍穹', 1);
    // ignore: avoid_print
    print('SEARCH issue=${search.issue.name} hits=${search.hits.length}');
    if (search.hits.isEmpty) {
      // ignore: avoid_print
      print('detail=${search.detail}');
      return;
    }
    final hit = search.hits.first;
    // ignore: avoid_print
    print('HIT name=${hit.name} bookUrl=${hit.bookUrl}');

    final resp = await AnalyzeUrl.fetch(source, '', absoluteUrl: hit.bookUrl);
    final head = resp.body.substring(0, resp.body.length.clamp(0, 400));
    // ignore: avoid_print
    print('isJson=${resp.isJson} len=${resp.body.length}');
    // ignore: avoid_print
    print('BODY_HEAD: $head');

    final all = AnalyzeRule(
      content: resp.body,
      baseUrl: resp.url,
      isJson: resp.isJson,
      jsLib: source.jsLib,
    );
    final initRule = source.ruleBookInfo.init;
    final initValue = all.getString(initRule);
    // ignore: avoid_print
    print('INIT="$initRule" -> len=${initValue.length} head=${initValue.substring(0, initValue.length.clamp(0, 200))}');

    final nameRule = source.ruleBookInfo.name;
    // ignore: avoid_print
    print('name(no init)="$nameRule" -> "${all.getString(nameRule)}"');

    if (initValue.isNotEmpty) {
      final sub = AnalyzeRule(
        content: initValue,
        baseUrl: resp.url,
        isJson: initValue.trimLeft().startsWith('{') ||
            initValue.trimLeft().startsWith('['),
      );
      // ignore: avoid_print
      print('name(after init) -> "${sub.getString(nameRule)}"');
    }
  },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: (Platform.environment['LANGHUAN_DEBUG_PACK'] ?? '').isEmpty
          ? 'set LANGHUAN_DEBUG_PACK to run'
          : false);
}
