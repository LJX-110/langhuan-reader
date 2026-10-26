import 'package:langhuan/features/sources/model/book_source.dart';

/// How a repository sync will affect the local source list.
class SourceSyncPlan {
  const SourceSyncPlan({required this.newCount, required this.existingCount});

  final int newCount;
  final int existingCount;

  bool get hasExisting => existingCount > 0;
  int get total => newCount + existingCount;
}

SourceSyncPlan buildSourceSyncPlan({
  required Iterable<String> incomingUrls,
  required Set<String> existingUrls,
}) {
  var newCount = 0;
  var existingCount = 0;
  final seen = <String>{};
  for (final url in incomingUrls) {
    if (url.isEmpty || !seen.add(url)) continue;
    if (existingUrls.contains(url)) {
      existingCount++;
    } else {
      newCount++;
    }
  }
  return SourceSyncPlan(newCount: newCount, existingCount: existingCount);
}

/// Read-only detection of repeated `local://` sources.
///
/// The importer mints a new id when a local source's content changes, so the
/// old row survives as a same-name duplicate. Nothing is deleted here; the UI
/// only reports the groups so the user can clean them up manually.
List<List<BookSource>> groupDuplicateLocalSources(List<BookSource> sources) {
  final groups = <String, List<BookSource>>{};
  for (final source in sources) {
    if (!source.bookSourceUrl.startsWith('local://')) continue;
    final name = source.bookSourceName.trim();
    final key = name.isEmpty ? source.bookSourceUrl : name;
    groups.putIfAbsent(key, () => []).add(source);
  }
  return groups.values
      .where((group) => group.length > 1)
      .toList(growable: false);
}
