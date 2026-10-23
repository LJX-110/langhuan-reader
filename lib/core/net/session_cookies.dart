/// In-memory session cookies shared by source requests and cover loads.
///
/// Cookies are host-scoped and never persisted; they live only for the app
/// process, mirroring the source session that produced them.
class SessionCookies {
  SessionCookies._();

  static final Map<String, Map<String, String>> _jar = {};

  /// `Cookie` header value for [url], or null when the jar has nothing.
  static String? headerForUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return null;
    final jar = _jar[host];
    if (jar == null || jar.isEmpty) return null;
    return jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Merge one response's `set-cookie` values into the host jar.
  static void saveFromSetCookie(String host, List<String> rawList) {
    if (host.isEmpty || rawList.isEmpty) return;
    final jar = _jar.putIfAbsent(host, () => <String, String>{});
    for (final raw in rawList) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      final lower = raw.toLowerCase();
      final expired =
          lower.contains('max-age=0') ||
          lower.contains('expires=thu, 01 jan 1970');
      if (expired || value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
  }

  static void clear() => _jar.clear();
}
