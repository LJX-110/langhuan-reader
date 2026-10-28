import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/import/source_validation.dart';

/// Opt-in live validation for a private source pack (used by the
/// `langhuan-sources` repo to generate `reports/validate-*.json`).
///
/// Run with:
///   `$env:LANGHUAN_VALIDATE_SOURCES='..\langhuan-sources\packages\all.json'`
///   `$env:LANGHUAN_VALIDATE_KEYWORD='斗破苍穹'`
///   `$env:LANGHUAN_VALIDATE_REPORT='..\langhuan-sources\reports\validate.json'`
///   `flutter test test/tools/source_validate_live_test.dart`
///
/// Skipped in the normal suite: it performs real network requests.
void main() {
  final packPath = Platform.environment['LANGHUAN_VALIDATE_SOURCES'] ?? '';
  final keyword =
      Platform.environment['LANGHUAN_VALIDATE_KEYWORD'] ?? '斗破苍穹';
  final reportPath = Platform.environment['LANGHUAN_VALIDATE_REPORT'] ?? '';

  group('live source validation', () {
    test('validates every source in the pack', () async {
      final file = File(packPath);
      if (!file.existsSync()) {
        // ignore: avoid_print
        print('SKIP pack not found: $packPath');
        return;
      }
      final parsed = SourceImporter.parseJson(file.readAsStringSync());
      final structure = SourceValidator.validate(parsed);
      final engine = BookSourceEngine();
      final rows = <Map<String, dynamic>>[];

      for (final source in parsed.sources) {
        final row = <String, dynamic>{
          'name': source.bookSourceName,
          'url': source.bookSourceUrl,
        };
        final issue = structure.items.firstWhere(
          (i) => i.source.bookSourceUrl == source.bookSourceUrl,
        );
        row['structure'] = issue.valid ? 'ok' : issue.problem;
        if (!issue.valid) {
          rows.add(row);
          continue;
        }

        final search = await engine.searchWithReport(source, keyword, 1);
        row['search'] = {
          'issue': search.issue.name,
          'hits': search.hits.length,
          'ms': search.elapsedMs,
          // Actionable diagnostics: which rule failed, how many raw rows the
          // list rule produced, and the HTTP status of the request.
          'detail': search.detail,
          'rawItems': search.rawItems,
          'http': search.httpStatus,
          'requestUrl': search.requestUrl,
        };

        final hit = search.hits.isEmpty ? null : search.hits.first;
        if (hit != null && hit.bookUrl.isNotEmpty) {
          final info = await engine.testBookInfo(source, hit.bookUrl);
          row['bookInfo'] = {
            'ok': info.ok,
            'ms': info.elapsedMs,
            'field': info.field,
            'detail': info.detail,
          };
          if (info.ok && info.tocUrl.isNotEmpty) {
            final toc = await engine.testToc(source, info.tocUrl);
            row['toc'] = {
              'ok': toc.ok,
              'chapters': toc.count,
              'ms': toc.elapsedMs,
              'field': toc.field,
              'detail': toc.detail,
            };
            if (toc.ok && toc.chapterUrl.isNotEmpty) {
              final content = await engine.testContent(source, toc.chapterUrl);
              row['content'] = {
                'ok': content.ok,
                'chars': content.count,
                'ms': content.elapsedMs,
                'field': content.field,
                'detail': content.detail,
              };
            }
          }
        }
        rows.add(row);
      }

      final report = {
        'generated': DateTime.now().toIso8601String(),
        'keyword': keyword,
        'total': parsed.sources.length,
        'sources': rows,
      };
      final text = const JsonEncoder.withIndent('  ').convert(report);
      if (reportPath.isNotEmpty) {
        final out = File(reportPath);
        await out.parent.create(recursive: true);
        await out.writeAsString(text, flush: true);
        // ignore: avoid_print
        print('VALIDATION REPORT written: $reportPath');
      } else {
        // ignore: avoid_print
        print(text);
      }
      expect(rows, hasLength(parsed.sources.length));
    }, timeout: const Timeout(Duration(minutes: 20)));
  }, skip: packPath.isEmpty ? 'set LANGHUAN_VALIDATE_SOURCES to run' : false);
}
