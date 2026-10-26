import 'dart:convert';

import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

/// How a manual import relates to sources already stored locally.
class SourceImportConflict {
  const SourceImportConflict({
    this.newCount = 0,
    this.changedCount = 0,
    this.unchangedCount = 0,
    this.changedUrls = const <String>{},
    this.unchangedUrls = const <String>{},
  });

  final int newCount;
  final int changedCount;
  final int unchangedCount;
  final Set<String> changedUrls;
  final Set<String> unchangedUrls;

  int get existingCount => changedCount + unchangedCount;
  bool get hasExisting => existingCount > 0;
  bool get hasChanged => changedCount > 0;

  /// Keep only new and genuinely changed sources.
  ///
  /// An overwrite must not rewrite rows whose rules already match the import;
  /// preserving them avoids meaningless updates and churn in sync timestamps.
  SourceParseResult withoutUnchanged(SourceParseResult parsed) {
    return SourceParseResult(
      sources: parsed.sources
          .where((source) => !unchangedUrls.contains(source.bookSourceUrl))
          .toList(growable: false),
      skipped: parsed.skipped,
      duplicatesInBatch: parsed.duplicatesInBatch,
    );
  }
}

/// Compare the rule payloads that affect reading, ignoring local-only state
/// such as the enabled flag, custom order and health timings.
bool sourceRulesEqual(BookSource a, BookSource b) {
  Map<String, dynamic> comparable(BookSource source) {
    final json = source.toLegadoJson();
    json.remove('enabled');
    json.remove('customOrder');
    json.remove('lastUpdateTime');
    json.remove('respondTime');
    return json;
  }

  return jsonEncode(comparable(a)) == jsonEncode(comparable(b));
}

SourceImportConflict buildSourceImportConflict({
  required Iterable<BookSource> incoming,
  required Iterable<BookSource> existing,
}) {
  final existingByUrl = <String, BookSource>{
    for (final source in existing)
      if (source.bookSourceUrl.isNotEmpty) source.bookSourceUrl: source,
  };
  final seen = <String>{};
  var newCount = 0;
  var changedCount = 0;
  var unchangedCount = 0;
  final changedUrls = <String>{};
  final unchangedUrls = <String>{};

  for (final source in incoming) {
    final url = source.bookSourceUrl;
    if (url.isEmpty || !seen.add(url)) continue;
    final old = existingByUrl[url];
    if (old == null) {
      newCount++;
    } else if (sourceRulesEqual(old, source)) {
      unchangedCount++;
      unchangedUrls.add(url);
    } else {
      changedCount++;
      changedUrls.add(url);
    }
  }

  return SourceImportConflict(
    newCount: newCount,
    changedCount: changedCount,
    unchangedCount: unchangedCount,
    changedUrls: changedUrls,
    unchangedUrls: unchangedUrls,
  );
}
