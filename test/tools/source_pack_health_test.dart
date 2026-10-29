import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';

/// 整包书源体检（并发只跑「搜索」这一步，快照式）。
///
///   $env:LANGHUAN_HEALTH_PACK='E:\WorkSpace\Novel\参考\1555书源.json'
///   $env:LANGHUAN_HEALTH_KEYWORD='斗破苍穹'
///   $env:LANGHUAN_HEALTH_OUT='E:\WorkSpace\Novel\备份\2026-10-29'
///   flutter test test/tools/source_pack_health_test.dart
///
/// 产出：`health.json`（每源一行）+ `health-summary.txt` +
/// `usable-sources.json`（搜索到结果的源，可直接做私有仓库源包）。
void main() {
  final packPath = Platform.environment['LANGHUAN_HEALTH_PACK'] ?? '';
  final keyword = Platform.environment['LANGHUAN_HEALTH_KEYWORD'] ?? '斗破苍穹';
  final outDir = Platform.environment['LANGHUAN_HEALTH_OUT'] ?? '';
  const concurrency = 8;

  test('pack health scan (search only)', () async {
    final parsed = SourceImporter.parseJson(
      File(packPath).readAsStringSync(),
    );
    final sources = parsed.sources
        .where((s) => s.enabled && s.searchUrl.trim().isNotEmpty)
        .toList();
    // ignore: avoid_print
    print('HEALTH start: ${sources.length} searchable / ${parsed.sources.length} parsed');

    final rows = <Map<String, dynamic>>[];
    final engine = BookSourceEngine();
    for (var i = 0; i < sources.length; i += concurrency) {
      final end = (i + concurrency).clamp(0, sources.length);
      final chunk = sources.sublist(i, end);
      final results = await Future.wait(
        chunk.map((source) async {
          final sw = Stopwatch()..start();
          try {
            final r = await engine.searchWithReport(source, keyword, 1);
            return <String, dynamic>{
              'name': source.bookSourceName,
              'url': source.bookSourceUrl,
              'issue': r.issue.name,
              'hits': r.hits.length,
              'ms': r.elapsedMs,
              'http': r.httpStatus,
              'raw': r.rawItems,
              'detail': r.detail,
            };
          } catch (e) {
            return <String, dynamic>{
              'name': source.bookSourceName,
              'url': source.bookSourceUrl,
              'issue': 'exception',
              'hits': 0,
              'ms': sw.elapsedMilliseconds,
              'detail': e.runtimeType.toString(),
            };
          }
        }),
      );
      rows.addAll(results);
      if ((i ~/ concurrency) % 10 == 0) {
        // ignore: avoid_print
        print('HEALTH progress ${rows.length}/${sources.length}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    final counts = <String, int>{};
    for (final r in rows) {
      final k = r['issue'] as String;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final ok = rows.where((r) => (r['hits'] as int) > 0).toList();

    if (outDir.isNotEmpty) {
      final dir = Directory(outDir);
      await dir.create(recursive: true);
      await File('${dir.path}/health.json')
          .writeAsString(const JsonEncoder.withIndent(' ').convert(rows));
      final usable = parsed.sources
          .where(
            (s) => ok.any((r) => r['url'] == s.bookSourceUrl),
          )
          .toList();
      // BookSource 不是 JSON 可编码对象：用 rawJson（原样导出）或 toLegadoJson。
      final usableJson = usable
          .map((s) {
            if (s.rawJson.isNotEmpty) {
              try {
                return jsonDecode(s.rawJson);
              } catch (_) {}
            }
            return s.toLegadoJson();
          })
          .toList();
      await File('${dir.path}/usable-sources.json')
          .writeAsString(const JsonEncoder.withIndent(' ').convert(usableJson));
      final summary = StringBuffer()
        ..writeln('pack=${parsed.sources.length} searchable=${sources.length}')
        ..writeln('keyword=$keyword')
        ..writeln('issue counts: $counts')
        ..writeln('with hits: ${ok.length}')
        ..writeln('usable pack: ${dir.path}\\usable-sources.json');
      for (final r in ok.take(60)) {
        summary.writeln('  ${r['hits']} 条  ${r['name']}  (${r['ms']}ms)');
      }
      await File('${dir.path}/health-summary.txt').writeAsString('$summary');
      // ignore: avoid_print
      print('HEALTH done. ${summary.toString().split('\n').take(4).join(' | ')}');
    }
    expect(rows.length, sources.length);
  },
      timeout: const Timeout(Duration(hours: 3)),
      skip: packPath.isEmpty ? 'set LANGHUAN_HEALTH_PACK to run' : false);
}
