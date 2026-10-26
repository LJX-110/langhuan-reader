/// Chapter / volume title normalisation shared by TOC, reader and search.
///
/// Only formatting noise is removed; the source's own wording (including
/// "第X章" numbering and book-name prefixes) is preserved verbatim.
String normalizeTitle(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = _decodeEntities(s);
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  // Zero-width characters used for anti-scraping spacing.
  s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  // Full-width space → normal space, then collapse whitespace.
  s = s.replaceAll('\u3000', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Leading / trailing separators like "第一章 -" or "· 第一卷".
  s = s.replaceAll(RegExp(r'^[\-—–·|｜:：,，.。]+'), '').trim();
  s = s.replaceAll(RegExp(r'[\-—–·|｜:：,，]+$'), '').trim();
  return s;
}

String _decodeEntities(String input) {
  if (!input.contains('&')) return input;
  var s = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  s = s.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (match) {
    final hex = match.group(1) == 'x';
    final code = int.tryParse(match.group(2)!, radix: hex ? 16 : 10);
    if (code == null || code <= 0 || code > 0x10FFFF) return match.group(0)!;
    try {
      return String.fromCharCode(code);
    } catch (_) {
      return match.group(0)!;
    }
  });
  return s;
}

/// Drop a duplicated volume prefix such as 「第一卷 第一章 初入江湖」.
String titleWithoutVolume(String title, String volume) {
  final t = title.trim();
  final v = volume.trim();
  if (v.isEmpty || !t.startsWith(v)) return t;
  final rest = t
      .substring(v.length)
      .replaceFirst(RegExp(r'^[\s\-—–·|｜:：]+'), '')
      .trim();
  return rest.isEmpty ? t : rest;
}

/// Reader-facing title.
///
/// The reader shows the chapter name only ([withVolume] exists for callers
/// that later want the composed form). Empty chapter names fall back to
/// 「第 N 章」 instead of inventing other wording.
String displayReadingTitle(
  String chapter, {
  String volume = '',
  int? index,
  bool withVolume = false,
}) {
  var title = normalizeTitle(chapter);
  if (title.isEmpty && index != null) {
    title = '第 ${index + 1} 章';
  }
  if (!withVolume) return title;
  final vol = normalizeTitle(volume);
  if (vol.isEmpty || title.isEmpty) return title;
  return '$vol · ${titleWithoutVolume(title, vol)}';
}
