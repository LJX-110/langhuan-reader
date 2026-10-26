import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/analyzer/js_analyzer.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/net/source_http.dart';

/// Opt-in live compatibility check for 阅友小说 (m.suixkan.com).
///
/// The book list keeps its detail link in `onclick`, and `bookUrl` is
/// `@onclick@js:result.match(...)[1]`, so this exercises the `@onclick`
/// attribute plus the trailing `@js:` transform end to end.
///
/// Run with:
///   $env:LANGHUAN_LIVE_SOURCE = '1'; flutter test test/source/yueyou_live_test.dart
///
/// Skipped in the normal suite so ordinary runs stay offline. The source pack
/// is fetched at runtime, never bundled: the app must not ship third-party
/// source rule text.
void main() {
  final enabled = Platform.environment['LANGHUAN_LIVE_SOURCE'] == '1';
  final packUrl =
      Platform.environment['LANGHUAN_SOURCE_JSON_URL'] ??
      'https://legado.aoaostar.com/sources/71e56d4f.json';

  group('阅友小说 live search', () {
    test('《斗破苍穹》 yields book paths from the onclick rule', () async {
      final pack = await SourceHttp.instance.fetch(
        AnalyzeRequest(url: packUrl),
      );
      final parsed = SourceImporter.parseJson(pack.body);
      final source = parsed.sources.firstWhere(
        (s) => s.bookSourceName == '阅友小说',
        orElse: () => throw StateError('阅友小说 not found in $packUrl'),
      );

      // The trailing @js: transform needs the JS runtime (QuickJS on Android).
      // Without it the rule degrades to the raw handler and the run is
      // meaningless — skip instead of reporting a false failure.
      final probe = JsEngine.instance.eval("'ok'", result: '');
      if (probe.trim() != 'ok') {
        // ignore: avoid_print
        print('SKIP JS runtime unavailable in this test host');
        return;
      }

      final hits = await BookSourceEngine().search(source, '斗破苍穹', 1);

      expect(hits, isNotEmpty);
      for (final hit in hits.take(3)) {
        expect(hit.name, isNotEmpty);
        // Raw `newWebView(...)` leftovers never match; /b/ proves the JS
        // transform extracted the path before it was sanitized and joined.
        expect(hit.bookUrl, contains('/b/'));
      }
    });
  }, skip: enabled ? false : 'set LANGHUAN_LIVE_SOURCE=1 to run');
}
