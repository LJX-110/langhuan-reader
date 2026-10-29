import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:langhuan/features/sources/analyzer/js_analyzer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/net/source_http.dart';
import 'package:langhuan/features/sources/util/url_join.dart';
import 'package:flutter/foundation.dart';

class AnalyzeRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final dynamic body;
  final String charset;

  AnalyzeRequest({
    required this.url,
    this.method = 'GET',
    Map<String, String>? headers,
    this.body,
    this.charset = 'utf-8',
  }) : headers = headers ?? {};
}

/// Build request from Legado-style searchUrl / absolute url + source header.
class AnalyzeUrl {
  /// [template] examples:
  /// - `https://x.com/search?q={{key}}&page={{page}}`
  /// - `https://x.com/s,{"method":"POST","body":"key={{key}}"}`
  /// 地址看着能用（非空、不是 JS 语句残渣）。
  static bool _urlUsable(String url) {
    final t = url.trim();
    return t.isNotEmpty && !_looksLikeJsStatement(t);
  }

  /// `java.ajax` 两阶段（Legado 的 `java.ajax` 是同步的，我们的 JS 桥是异步的，
  /// 所以拆成两次执行）：
  ///
  /// 1. 阶段 A：`java.ajax` 换成"记录调用 + 返回空串"的桩，跑一遍脚本拿到它
  ///    要请求的 `url,{options}`；
  /// 2. Dart 侧用本应用网络栈抓这些地址（复用 `build` 的 `url,{options}`
  ///    解析：gbk / POST / headers 都一致）；
  /// 3. 阶段 B：把响应按 URL 注入后重跑脚本，拿到最终地址再交给 [build]。
  ///
  /// 最多两轮；拿不到就返回 null，调用方继续走原有的失败路径。
  static Future<AnalyzeRequest?> _buildWithAjax(
    BookSource source,
    String template, {
    required String key,
    required int page,
  }) async {
    try {
      var code = JsEngine.extractCode(template) ?? template;
      final host = hostOf(source.bookSourceUrl);
      final encodedKey = encodeKey(key, _charsetHint(template));
      code = code
          .replaceAll('{{key}}', encodedKey)
          .replaceAll('{{page}}', '$page')
          .replaceAll('{{host}}', host)
          .replaceAll('{key}', encodedKey)
          .replaceAll('{page}', '$page');
      final script = code.contains('result') ? '$code\n;result' : code;
      JsEngine.instance.ensureSource(bookSourceUrl: source.bookSourceUrl);

      for (var round = 0; round < 2; round++) {
        final recorded = JsEngine.instance.evalRecordingAjax(
          script,
          result: '',
          baseUrl: source.bookSourceUrl,
          src: '',
          jsLib: source.jsLib,
        );
        final calls = recorded.ajax
            .where((c) => c.trim().isNotEmpty)
            .toList(growable: false);
        if (calls.isEmpty) return null;

        final responses = <String, String>{};
        for (final call in calls.take(6)) {
          try {
            final sub = build(source, call, key: key, page: page);
            final resp = await SourceHttp.instance.fetch(sub);
            responses[call] = resp.body;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[AnalyzeUrl] java.ajax fetch failed: $e');
            }
          }
        }
        if (responses.isEmpty) return null;

        final out = JsEngine.instance
            .evalWithAjaxResponses(
              script,
              responses,
              result: '',
              baseUrl: source.bookSourceUrl,
              src: '',
              jsLib: source.jsLib,
            )
            .trim();
        if (out.isEmpty || _looksLikeJsStatement(out)) continue;
        final req = build(source, out, key: key, page: page);
        if (_urlUsable(req.url)) {
          if (kDebugMode) {
            debugPrint(
              '[AnalyzeUrl] java.ajax two-phase ok for '
              '"${source.bookSourceName}" round=$round ajax=${calls.length}',
            );
          }
          return req;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyzeUrl] ajax two-phase failed: $e');
    }
    return null;
  }

  /// 把 `@js:` / `<js>` 模板解析成**原始地址字符串**（同步、不发请求）。
  ///
  /// 抽出来是为了让异步入口 [fetch] 能在"脚本自己给不出地址"时接上
  /// `java.ajax` 两阶段：先用这里拿到脚本、记录它要抓的地址，抓完再用
  /// [JsEngine.evalWithAjaxResponses] 重跑。给不出地址时返回空串。
  static String _resolveTemplateUrl(
    BookSource source,
    String template, {
    String key = '',
    int page = 1,
  }) {
    var raw = template.trim();
    if (!JsEngine.needsJs(raw)) return raw;
    if (source.jsLib.isNotEmpty) {
      JsEngine.instance.ensureJsLib(source.jsLib);
    }
    var code = JsEngine.extractCode(raw) ?? raw;
    final host = hostOf(source.bookSourceUrl);
    final encodedKey = encodeKey(key, _charsetHint(raw));
    code = code
        .replaceAll('{{key}}', encodedKey)
        .replaceAll('{{page}}', '$page')
        .replaceAll('{{host}}', host)
        .replaceAll('{key}', encodedKey)
        .replaceAll('{page}', '$page');

    // Quirk path: `url,{opts};result=…` → use url,{opts} as template.
    final quirk = RegExp(
      r"^([^;]+);\s*result\s*=",
      multiLine: true,
    ).firstMatch(code.trim());
    if (quirk != null) return quirk.group(1)!.trim();

    // `source` 绑定先就位：`source.getKey()` 等要能拿到当前书源。
    JsEngine.instance.ensureSource(bookSourceUrl: source.bookSourceUrl);
    final evaluated = JsEngine.instance.eval(
      // Ensure we produce a value: append `; result` if script uses result=
      code.contains('result') ? '$code\n;result' : code,
      result: '',
      baseUrl: source.bookSourceUrl,
      src: '',
      jsLib: source.jsLib,
    );
    final out = evaluated.trim();
    // On failure JS returns empty / leftover statements — never treat the
    // original script body as a URL (Uri.resolve would throw).
    if (out.isEmpty || _looksLikeJsStatement(out)) {
      if (kDebugMode) {
        debugPrint(
          '[AnalyzeUrl] JS searchUrl/exploreUrl did not yield a URL '
          'for "${source.bookSourceName}" '
          '(out="${_clip(out.isEmpty ? code : out)}")',
        );
      }
      return '';
    }
    if (out.contains('<js>') || out.startsWith('@js:')) {
      return JsEngine.extractCode(out) ?? out;
    }
    return out;
  }

  static AnalyzeRequest build(
    BookSource source,
    String template, {
    String key = '',
    int page = 1,
    Map<String, String>? extraHeaders,
  }) {
    var raw = template.trim();
    var method = 'GET';
    dynamic body;
    // Legado sources declare `{"charset":"gbk"}` in url options; the same
    // charset must encode Chinese search keys, not only decode responses.
    var charset = _charsetHint(raw);
    Map<String, String> headers = {};

    // Merge source header JSON if present
    headers.addAll(_parseHeader(source.header));
    if (extraHeaders != null) headers.addAll(extraHeaders);

    // Legado JS searchUrl / exploreUrl.
    // Two shapes:
    // 1) Real JS that assigns/returns a url string
    // 2) Quirk: `<js>/path,{'method':'POST',...};result='';result;</js>`
    //    (URL template disguised as JS — not valid JS expression)
    if (JsEngine.needsJs(raw)) {
      raw = _resolveTemplateUrl(source, raw, key: key, page: page);
    }

    // Options after comma: url,{json}  (JSON may use single quotes).
    final comma = _findOptionsComma(raw);
    if (comma > 0) {
      final optStr = raw.substring(comma + 1).trim();
      raw = raw.substring(0, comma).trim();
      try {
        final opt = jsonDecode(_jsonish(optStr));
        if (opt is Map) {
          if (opt['method'] != null) {
            method = opt['method'].toString().toUpperCase();
          }
          if (opt['body'] != null) body = opt['body'];
          if (opt['charset'] != null) {
            charset = opt['charset'].toString();
          }
          if (opt['headers'] is Map) {
            (opt['headers'] as Map).forEach((k, v) {
              _putHeader(headers, k.toString(), v.toString());
            });
          }
        }
      } catch (_) {}
    }

    final host = hostOf(source.bookSourceUrl);
    final encodedKey = encodeKey(key, charset);
    String fill(String s) {
      return s
          .replaceAll('{{key}}', encodedKey)
          .replaceAll('{{page}}', '$page')
          .replaceAll('{{host}}', host)
          .replaceAll('{{sourceUrl}}', source.bookSourceUrl)
          .replaceAll('{key}', encodedKey)
          .replaceAll('{page}', '$page')
          .replaceAll('{host}', host);
    }

    raw = fill(raw);
    if (body is String) body = fill(body);

    // Relative path from JS template → join against source host.
    if (raw.startsWith('/') && source.bookSourceUrl.isNotEmpty) {
      raw = urlJoin(source.bookSourceUrl, raw);
    }

    // Drop leftover Legado JS snippets (cookie/js helpers we don't evaluate)
    // e.g. `{{cookie.removeCookie(source.getKey())}}http://…`
    raw = sanitizeUrl(raw, base: source.bookSourceUrl);
    if (body is String) {
      // body may also carry {{…}} noise; only strip, don't force URL join.
      body = _stripJsTemplates(body);
    }

    return AnalyzeRequest(
      url: raw,
      method: method,
      headers: headers,
      body: body,
      charset: charset,
    );
  }

  /// Encode a search key for query strings and form bodies.
  ///
  /// GBK/Big5-era novel sites expect percent-encoded bytes in their declared
  /// charset; UTF-8 percent encoding makes Chinese keys come back empty.
  static String encodeKey(String key, String charset) {
    final c = charset.toLowerCase().replaceAll('_', '-');
    final gbkFamily =
        c.contains('gbk') || c.contains('gb2312') || c.contains('gb18030');
    if (!gbkFamily) return Uri.encodeQueryComponent(key);
    try {
      final out = StringBuffer();
      for (final b in gbk.encode(key)) {
        if (b == 0x20) {
          out.write('+');
        } else if (_isUnreserved(b)) {
          out.writeCharCode(b);
        } else {
          out.write('%');
          out.write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
        }
      }
      return out.toString();
    } catch (_) {
      return Uri.encodeQueryComponent(key);
    }
  }

  static bool _isUnreserved(int b) =>
      (b >= 0x41 && b <= 0x5A) ||
      (b >= 0x61 && b <= 0x7A) ||
      (b >= 0x30 && b <= 0x39) ||
      b == 0x2D ||
      b == 0x2E ||
      b == 0x5F ||
      b == 0x7E;

  static final RegExp _charsetPattern = RegExp(
    '''charset["']?\\s*[:=]\\s*["']?([a-zA-Z0-9_-]+)''',
    caseSensitive: false,
  );

  static String _charsetHint(String template) {
    final match = _charsetPattern.firstMatch(template);
    return (match?.group(1) ?? 'utf-8').toLowerCase();
  }

  /// Accept single-quoted JS object literals as JSON.
  static String _jsonish(String s) {
    var t = s.trim();
    // `{'method':'POST'}` → `{"method":"POST"}`
    if (t.contains("'")) {
      t = t.replaceAll("'", '"');
    }
    return t;
  }

  static Future<SourceResponse> fetch(
    BookSource source,
    String template, {
    String key = '',
    int page = 1,
    String? absoluteUrl,
  }) async {
    AnalyzeRequest req;
    if (absoluteUrl != null && absoluteUrl.isNotEmpty) {
      req = AnalyzeRequest(
        url: sanitizeUrl(absoluteUrl, base: source.bookSourceUrl),
        headers: _parseHeader(source.header),
      );
    } else {
      req = build(source, template, key: key, page: page);
      // `java.ajax` 两阶段：脚本要先抓别的页面才能拼出地址时才走这条新路，
      // 走得通的源（绝大多数）完全不受影响。
      if (JsEngine.needsJs(template) && !_urlUsable(req.url)) {
        req = await _buildWithAjax(source, template, key: key, page: page) ?? req;
      }
    }
    return SourceHttp.instance.fetch(req);
  }

  /// Make a Legado-style URL safe for Dio / Uri.parse.
  ///
  /// Strips unevaluated `{{…}}` JS helpers, recovers the first http(s) URL if
  /// one is embedded, and joins relative paths against [base].
  ///
  /// Returns empty when the input cannot be turned into an absolute http(s)
  /// URL (e.g. leftover JS after a failed `@js` evaluation).
  static String sanitizeUrl(String input, {String base = ''}) {
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
        debugPrint('[AnalyzeUrl] reject non-URL "${_clip(original)}"');
      }
      return '';
    }

    if (!_looksAbsolute(raw) && base.isNotEmpty) {
      raw = urlJoin(base, raw);
    }
    // Drop control chars / whitespace that break Dio Uri.parse.
    raw = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (!_looksAbsolute(raw)) {
      // Relative without a usable base, or join still failed / rejected.
      return '';
    }
    if (kDebugMode && original.contains('{{') && original != raw) {
      debugPrint(
        '[AnalyzeUrl] sanitized "${_clip(original)}" → "${_clip(raw)}"',
      );
    }
    return raw;
  }

  /// Detect leftover Legado JS that must never be fed to [Uri.resolve].
  static bool _looksLikeJsStatement(String s) {
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

  static String _clip(String s, [int n = 120]) =>
      s.length <= n ? s : '${s.substring(0, n)}…';

  /// Remove `{{ … }}` blocks (non-greedy). Known placeholders are filled first.
  static String _stripJsTemplates(String s) {
    if (!s.contains('{{')) return s;
    return s.replaceAll(RegExp(r'\{\{[\s\S]*?\}\}'), '').trim();
  }

  static bool _looksAbsolute(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  /// First http(s) URL substring, if any.
  static String? _firstHttpUrl(String s) {
    final m = RegExp(r'''https?://[^\s"'<>]+''').firstMatch(s);
    return m?.group(0);
  }

  static Map<String, String> _parseHeader(String header) {
    final map = <String, String>{};
    if (header.isEmpty) return map;
    try {
      final obj = jsonDecode(header);
      if (obj is Map) {
        obj.forEach((k, v) => _putHeader(map, k.toString(), v.toString()));
      }
    } catch (_) {
      // plain "Key: Value" lines
      for (final line in header.split(RegExp(r'[\r\n]+'))) {
        final i = line.indexOf(':');
        if (i > 0) {
          _putHeader(
            map,
            line.substring(0, i).trim(),
            line.substring(i + 1).trim(),
          );
        }
      }
    }
    return map;
  }

  /// Keep only valid HTTP header field names.
  ///
  /// Legado sources often put `@js` / `@Header:` style keys in `header` JSON;
  /// Dio rejects those names (`FormatException: Invalid HTTP header field name`).
  static void _putHeader(Map<String, String> map, String key, String value) {
    final k = key.trim();
    if (k.isEmpty) return;
    // Skip Legado rule markers and other non-token names.
    if (k.startsWith('@')) return;
    if (!_isValidHeaderName(k)) return;
    map[k] = value;
  }

  /// RFC 7230 token: tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" /
  ///   "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
  static bool _isValidHeaderName(String name) {
    if (name.isEmpty) return false;
    for (var i = 0; i < name.length; i++) {
      final c = name.codeUnitAt(i);
      final ok =
          (c >= 0x30 && c <= 0x39) || // 0-9
          (c >= 0x41 && c <= 0x5a) || // A-Z
          (c >= 0x61 && c <= 0x7a) || // a-z
          c == 0x21 || // !
          c == 0x23 || // #
          c == 0x24 || // $
          c == 0x25 || // %
          c == 0x26 || // &
          c == 0x27 || // '
          c == 0x2a || // *
          c == 0x2b || // +
          c == 0x2d || // -
          c == 0x2e || // .
          c == 0x5e || // ^
          c == 0x5f || // _
          c == 0x60 || // `
          c == 0x7c || // |
          c == 0x7e; // ~
      if (!ok) return false;
    }
    return true;
  }

  static int _findOptionsComma(String raw) {
    // last comma before a `{` options object
    final idx = raw.lastIndexOf(',{');
    return idx;
  }
}

/// Lightweight response holder (avoids tight Dio coupling in analyzers).
class SourceResponse {
  final String url;
  final String body;
  final String contentType;
  final int statusCode;

  SourceResponse({
    required this.url,
    required this.body,
    this.contentType = 'text/html',
    this.statusCode = 200,
  });

  bool get isJson =>
      contentType.contains('json') ||
      body.trimLeft().startsWith('{') ||
      body.trimLeft().startsWith('[');
}
