/// URL sanitising for diagnostics, logs and UI.
///
/// Book-source request URLs often carry tokens, session ids or cookies in the
/// query string. Never show a raw request URL to the user or write it to a
/// report: keep only scheme, host, port and path.
class Redact {
  const Redact._();

  /// `https://user:pw@host:8080/a/b?token=x#frag`
  /// → `https://host:8080/a/b?…`
  ///
  /// Returns an empty string for non-HTTP(S) or unparseable input.
  static String url(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return '';
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return '';
    if (uri.host.isEmpty) return '';
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?…' : '';
    final fragment = uri.hasFragment ? '#…' : '';
    return '${uri.origin}$path$query$fragment';
  }

  /// URL for log lines and reports.
  ///
  /// Redacts when the input parses as HTTP(S); keeps short non-URL labels
  /// (source names, relative paths) but hides anything else that carries a
  /// query string, which is where tokens and cookies live.
  static String forLog(String raw) {
    final redacted = url(raw);
    if (redacted.isNotEmpty) return redacted;
    return raw.contains('?') ? '(url hidden)' : raw;
  }

  /// Human-readable exception text without embedding request URLs.
  ///
  /// Prefer mapping exception types at the call site; this is only a fallback
  /// for messages that are known to be short and URL-free.
  static String errorType(Object error) => error.runtimeType.toString();
}
