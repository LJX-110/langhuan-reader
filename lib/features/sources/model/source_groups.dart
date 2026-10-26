import 'package:langhuan/features/sources/model/book_source.dart';

/// Group helpers for book sources.
///
/// Legado stores groups as a comma-separated string ("小说,备用"); a source
/// belongs to every token. Group filtering only scopes what is shown or
/// searched — it never rewrites stored rules.
class SourceGroups {
  const SourceGroups._();

  static List<String> of(BookSource source) => parse(source.bookSourceGroup);

  static List<String> parse(String raw) {
    final out = <String>[];
    for (final part in raw.split(RegExp(r'[,，;；]'))) {
      final group = part.trim();
      if (group.isEmpty || out.contains(group)) continue;
      out.add(group);
    }
    return out;
  }

  /// Distinct groups across [sources], ordered by first appearance.
  static List<String> collect(Iterable<BookSource> sources) {
    final out = <String>[];
    for (final source in sources) {
      for (final group in of(source)) {
        if (!out.contains(group)) out.add(group);
      }
    }
    return out;
  }

  /// True when [group] is empty (全部) or the source belongs to it.
  static bool matches(BookSource source, String group) {
    final wanted = group.trim();
    if (wanted.isEmpty) return true;
    return of(source).contains(wanted);
  }

  static List<BookSource> filter(Iterable<BookSource> sources, String group) =>
      [
        for (final source in sources)
          if (matches(source, group)) source,
      ];
}
