import 'package:flutter/foundation.dart';

import 'package:langhuan/features/sources/util/url_join.dart';

/// 从规则输出里净化出可请求的 http(s) URL。
///
/// 与阅读内核 `AnalyzeUrl.sanitizeUrl` 语义一致的纯工具：
/// 去掉未求值的 `{{…}}` JS 片段、回收嵌入的 http(s) 地址、拒绝 JS 语句
/// 残留，并把相对路径按 [base] 拼成绝对地址；无法还原时返回空串。
String sanitizeUrl(String input, {String base = ''}) {
  final original = input.trim();
  final lower = original.toLowerCase();
  // Handler leftovers are not links: many sites use href="javascript:;"
  // and keep the real book id in onclick.
  if (lower.startsWith('javascript:') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('tel:')) {
    return '';
  }
  if (original.startsWith('#')) return '';
  var raw = _stripJsTemplates(original);
  if (raw.isEmpty) return raw;

  // Recover `…noise…https://host/path` left after failed JS evaluation.
  if (!_looksAbsolute(raw)) {
    final embedded = _firstHttpUrl(raw);
    if (embedded != null) {
      raw = embedded;
    }
  }

  // Do not join JS statements / non-paths onto the host.
  if (!_looksAbsolute(raw) && _looksLikeJsStatement(raw)) {
    if (kDebugMode) {
      debugPrint('[sanitizeUrl] reject non-URL "${_clip(original)}"');
    }
    return '';
  }

  if (!_looksAbsolute(raw) && base.isNotEmpty) {
    raw = urlJoin(base, raw);
  }
  // Drop control chars / whitespace that break Uri.parse.
  raw = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (!_looksAbsolute(raw)) {
    // Relative without a usable base, or join still failed / rejected.
    return '';
  }
  if (kDebugMode && original.contains('{{') && original != raw) {
    debugPrint(
      '[sanitizeUrl] sanitized "${_clip(original)}" → "${_clip(raw)}"',
    );
  }
  return raw;
}

/// Detect leftover Legado JS that must never be fed to [Uri.resolve].
bool _looksLikeJsStatement(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  if (t.contains('<js>') || t.startsWith('@js:')) return true;
  if (t.contains('\n')) return true;
  if (RegExp(r'^\s*(let|var|const|function|return)\b').hasMatch(t)) {
    return true;
  }
  if (t.contains(';') &&
      RegExp(
        r'\b(let|var|const|function|getArguments|getVariable)\b',
      ).hasMatch(t)) {
    return true;
  }
  // Inline handler body left after a failed @onclick@js transform:
  //   openBook('123','','')
  if (RegExp(r"^[\w$.]+\s*\([^/]*\)\s*$").hasMatch(t) &&
      (t.contains("'") || t.contains('"'))) {
    return true;
  }
  return false;
}

String _clip(String s, [int n = 120]) =>
    s.length <= n ? s : '${s.substring(0, n)}…';

/// Remove `{{ … }}` blocks (non-greedy).
String _stripJsTemplates(String s) {
  if (!s.contains('{{')) return s;
  return s.replaceAll(RegExp(r'\{\{[\s\S]*?\}\}'), '').trim();
}

bool _looksAbsolute(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

/// First http(s) URL substring, if any.
String? _firstHttpUrl(String s) {
  final m = RegExp(r'''https?://[^\s"'<>]+''').firstMatch(s);
  return m?.group(0);
}
