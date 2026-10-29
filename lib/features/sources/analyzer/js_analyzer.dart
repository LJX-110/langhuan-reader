import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

/// Minimal Legado-style JS host for book-source rules.
///
/// Supported inputs:
/// - rule starts with `@js:`
/// - rule / content contains `<js>...</js>`
///
/// Injected bindings (subset of Legado):
/// - `result`  previous stage text / current content
/// - `baseUrl` page url
/// - `src`     full page body (alias of result when not chained)
/// - `java`    tiny helper object (stubs for CF / browser APIs)
/// - optional [jsLib] helpers (`cfCheck`, etc.) loaded per source
///
/// Returns string, or JSON-encoded list/map when JS returns array/object.
class JsEngine {
  JsEngine._();
  static final JsEngine instance = JsEngine._();

  JavascriptRuntime? _rt;
  bool _failed = false;
  String _loadedJsLib = '';

  JavascriptRuntime? get _runtime {
    if (_failed) return null;
    if (_rt != null) return _rt;
    try {
      _rt = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);
      // Lightweight polyfills commonly expected by source snippets.
      // java.startBrowserAwait / longToast are stubs: return original body
      // so CF-gated sources degrade to "no challenge rewrite" instead of crash.
      final init = _rt!.evaluate(r'''
var java = {
  getString: function(x){ return String(x==null?'':x); },
  ajax: function(){ return ''; },
  longToast: function(msg){},
  startBrowserAwait: function(url, title){
    return { body: function(){ return ''; }, url: String(url||'') };
  }
};
// Legado helpers used by many searchUrl @js snippets.
function getArguments(vars, key) {
  if (vars == null || key == null) return '';
  var s = String(vars);
  var k = String(key);
  try {
    var o = JSON.parse(s);
    if (o && o[k] != null) return String(o[k]);
  } catch (e) {}
  // query / comma form: key=value&… or key=value,…
  var re = new RegExp('(?:^|[,;&\\s])' + k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '=([^,;&\\s]*)');
  var m = s.match(re);
  if (m) {
    try { return decodeURIComponent(m[1]); } catch (e2) { return m[1]; }
  }
  return '';
}
var source = source || {
  getVariable: function(){ return ''; },
  getKey: function(){ return ''; },
  bookSourceUrl: ''
};
if (typeof String.prototype.endsWith !== 'function') {
  String.prototype.endsWith = function(s) {
    s = String(s);
    return this.length >= s.length && this.substring(this.length - s.length) === s;
  };
}
if (typeof String.prototype.startsWith !== 'function') {
  String.prototype.startsWith = function(s) {
    s = String(s);
    return this.substring(0, s.length) === s;
  };
}
function cfCheck(html, targetUrl){ return String(html==null?'':html); }

// ---- Legado java.* helpers commonly used by search/bookUrl/toc snippets ----
java.encodeURI = function(str, enc){ try { return encodeURI(String(str==null?'':str)); } catch (e) { return ''; } };
java.encodeURIComponent = function(str){ try { return encodeURIComponent(String(str==null?'':str)); } catch (e) { return ''; } };
java.log = function(msg){ return msg; };
java.toastLog = java.log;
java.timeFormat = function(ts){
  var n = Number(ts); if (!isFinite(n) || n <= 0) return '';
  var d = new Date(n < 1e12 ? n * 1000 : n);
  function p(x){ return (x < 10 ? '0' : '') + x; }
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
    ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
};
java.randomUUID = function(){
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c){
    var r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};
// Traditional ↔ simplified needs a full mapping table; identity keeps
// sources working instead of throwing.
java.t2s = function(s){ return String(s==null?'':s); };
java.s2t = java.t2s;
java.getWebViewUA = function(){
  return 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
};
var __b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
function __b64encode(str){
  var s = String(str == null ? '' : str);
  var utf8 = unescape(encodeURIComponent(s));
  var out = '', i = 0;
  while (i < utf8.length) {
    var c1 = utf8.charCodeAt(i++), c2 = utf8.charCodeAt(i++), c3 = utf8.charCodeAt(i++);
    var e1 = c1 >> 2, e2 = ((c1 & 3) << 4) | (c2 >> 4);
    var e3 = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (c3 >> 6));
    var e4 = isNaN(c3) ? 64 : (c3 & 63);
    out += __b64chars.charAt(e1) + __b64chars.charAt(e2) +
      __b64chars.charAt(e3) + __b64chars.charAt(e4);
  }
  return out;
}
function __b64decode(str){
  var s = String(str == null ? '' : str).replace(/[^A-Za-z0-9+/=]/g, '');
  var out = '', i = 0;
  while (i < s.length) {
    var e1 = __b64chars.indexOf(s.charAt(i++)), e2 = __b64chars.indexOf(s.charAt(i++));
    var e3 = __b64chars.indexOf(s.charAt(i++)), e4 = __b64chars.indexOf(s.charAt(i++));
    var c1 = (e1 << 2) | (e2 >> 4), c2 = ((e2 & 15) << 4) | (e3 >> 2);
    var c3 = ((e3 & 3) << 6) | e4;
    out += String.fromCharCode(c1);
    if (e3 !== 64 && e3 !== -1) out += String.fromCharCode(c2);
    if (e4 !== 64 && e4 !== -1) out += String.fromCharCode(c3);
  }
  try { return decodeURIComponent(escape(out)); } catch (e) { return out; }
}
java.base64Encode = __b64encode;
java.base64Decode = __b64decode;
java.base64DecodeToByteArray = __b64decode;
function __md5(s){
  function rl(n, c){ return (n << c) | (n >>> (32 - c)); }
  function au(x, y){ var l = (x & 0xFFFF) + (y & 0xFFFF); return (((x >> 16) + (y >> 16) + (l >> 16)) << 16) | (l & 0xFFFF); }
  function cmn(q, a, b, x, s, t){ return au(rl(au(au(a, q), au(x, t)), s), b); }
  function ff(a, b, c, d, x, s, t){ return cmn((b & c) | (~b & d), a, b, x, s, t); }
  function gg(a, b, c, d, x, s, t){ return cmn((b & d) | (c & ~d), a, b, x, s, t); }
  function hh(a, b, c, d, x, s, t){ return cmn(b ^ c ^ d, a, b, x, s, t); }
  function ii(a, b, c, d, x, s, t){ return cmn(c ^ (b | ~d), a, b, x, s, t); }
  function toBlocks(str){
    var utf8 = unescape(encodeURIComponent(String(str == null ? '' : str)));
    var n = utf8.length, words = [], i;
    for (i = 0; i < n; i++) words[i >> 2] = (words[i >> 2] || 0) | (utf8.charCodeAt(i) << ((i % 4) * 8));
    words[n >> 2] = (words[n >> 2] || 0) | (0x80 << ((n % 4) * 8));
    words[(((n + 8) >> 6) + 1) * 16 - 2] = n * 8;
    words[(((n + 8) >> 6) + 1) * 16 - 1] = Math.floor(n * 8 / 0x100000000);
    return words;
  }
  var x = toBlocks(s), a = 1732584193, b = -271733879, c = -1732584194, d = 271733878;
  for (var i = 0; i < x.length; i += 16) {
    var oa = a, ob = b, oc = c, od = d;
    a = ff(a, b, c, d, x[i] | 0, 7, -680876936); d = ff(d, a, b, c, x[i + 1] | 0, 12, -389564586);
    c = ff(c, d, a, b, x[i + 2] | 0, 17, 606105819); b = ff(b, c, d, a, x[i + 3] | 0, 22, -1044525330);
    a = ff(a, b, c, d, x[i + 4] | 0, 7, -176418897); d = ff(d, a, b, c, x[i + 5] | 0, 12, 1200080426);
    c = ff(c, d, a, b, x[i + 6] | 0, 17, -1473231341); b = ff(b, c, d, a, x[i + 7] | 0, 22, -45705983);
    a = ff(a, b, c, d, x[i + 8] | 0, 7, 1770035416); d = ff(d, a, b, c, x[i + 9] | 0, 12, -1958414417);
    c = ff(c, d, a, b, x[i + 10] | 0, 17, -42063); b = ff(b, c, d, a, x[i + 11] | 0, 22, -1990404162);
    a = ff(a, b, c, d, x[i + 12] | 0, 7, 1804603682); d = ff(d, a, b, c, x[i + 13] | 0, 12, -40341101);
    c = ff(c, d, a, b, x[i + 14] | 0, 17, -1502002290); b = ff(b, c, d, a, x[i + 15] | 0, 22, 1236535329);
    a = gg(a, b, c, d, x[i + 1] | 0, 5, -165796510); d = gg(d, a, b, c, x[i + 6] | 0, 9, -1069501632);
    c = gg(c, d, a, b, x[i + 11] | 0, 14, 643717713); b = gg(b, c, d, a, x[i] | 0, 20, -373897302);
    a = gg(a, b, c, d, x[i + 5] | 0, 5, -701558691); d = gg(d, a, b, c, x[i + 10] | 0, 9, 38016083);
    c = gg(c, d, a, b, x[i + 15] | 0, 14, -660478335); b = gg(b, c, d, a, x[i + 4] | 0, 20, -405537848);
    a = gg(a, b, c, d, x[i + 9] | 0, 5, 568446438); d = gg(d, a, b, c, x[i + 14] | 0, 9, -1019803690);
    c = gg(c, d, a, b, x[i + 3] | 0, 14, -187363961); b = gg(b, c, d, a, x[i + 8] | 0, 20, 1163531501);
    a = gg(a, b, c, d, x[i + 13] | 0, 5, -1444681467); d = gg(d, a, b, c, x[i + 2] | 0, 9, -51403784);
    c = gg(c, d, a, b, x[i + 7] | 0, 14, 1735328473); b = gg(b, c, d, a, x[i + 12] | 0, 20, -1926607734);
    a = hh(a, b, c, d, x[i + 5] | 0, 4, -378558); d = hh(d, a, b, c, x[i + 8] | 0, 11, -2022574463);
    c = hh(c, d, a, b, x[i + 11] | 0, 16, 1839030562); b = hh(b, c, d, a, x[i + 14] | 0, 23, -35309556);
    a = hh(a, b, c, d, x[i + 1] | 0, 4, -1530992060); d = hh(d, a, b, c, x[i + 4] | 0, 11, 1272893353);
    c = hh(c, d, a, b, x[i + 7] | 0, 16, -155497632); b = hh(b, c, d, a, x[i + 10] | 0, 23, -1094730640);
    a = hh(a, b, c, d, x[i + 13] | 0, 4, 681279174); d = hh(d, a, b, c, x[i] | 0, 11, -358537222);
    c = hh(c, d, a, b, x[i + 3] | 0, 16, -722521979); b = hh(b, c, d, a, x[i + 6] | 0, 23, 76029189);
    a = hh(a, b, c, d, x[i + 9] | 0, 4, -640364487); d = hh(d, a, b, c, x[i + 12] | 0, 11, -421815835);
    c = hh(c, d, a, b, x[i + 15] | 0, 16, 530742520); b = hh(b, c, d, a, x[i + 2] | 0, 23, -995338651);
    a = ii(a, b, c, d, x[i] | 0, 6, -198630844); d = ii(d, a, b, c, x[i + 7] | 0, 10, 1126891415);
    c = ii(c, d, a, b, x[i + 14] | 0, 15, -1416354905); b = ii(b, c, d, a, x[i + 5] | 0, 21, -57434055);
    a = ii(a, b, c, d, x[i + 12] | 0, 6, 1700485571); d = ii(d, a, b, c, x[i + 3] | 0, 10, -1894986606);
    c = ii(c, d, a, b, x[i + 10] | 0, 15, -1051523); b = ii(b, c, d, a, x[i + 1] | 0, 21, -2054922799);
    a = ii(a, b, c, d, x[i + 8] | 0, 6, 1873313359); d = ii(d, a, b, c, x[i + 15] | 0, 10, -30611744);
    c = ii(c, d, a, b, x[i + 6] | 0, 15, -1560198380); b = ii(b, c, d, a, x[i + 13] | 0, 21, 1309151649);
    a = ii(a, b, c, d, x[i + 4] | 0, 6, -145523070); d = ii(d, a, b, c, x[i + 11] | 0, 10, -1120210379);
    c = ii(c, d, a, b, x[i + 2] | 0, 15, 718787259); b = ii(b, c, d, a, x[i + 9] | 0, 21, -343485551);
    a = au(a, oa); b = au(b, ob); c = au(c, oc); d = au(d, od);
  }
  function hex(n){ var s = '', i; for (i = 0; i < 4; i++) s += ('0' + ((n >> (i * 8)) & 0xFF).toString(16)).slice(-2); return s; }
  return hex(a) + hex(b) + hex(c) + hex(d);
}
java.md5Encode = __md5;
java.md5Encode16 = function(s){ return __md5(s).substring(8, 24); };
java.HMacHex = function(){ return ''; };
java.digestHex = function(){ return ''; };

// Minimal Jsoup surface: sources use `org.jsoup.Jsoup.parse(html).html()` /
// `.text()` to post-process a fetched page. CSS `select()` needs a full
// selector engine, so it returns an empty list instead of throwing.
var org = {
  jsoup: {
    Jsoup: {
      parse: function(html){
        var h = String(html == null ? '' : html);
        return {
          html: function(){ return h; },
          outerHtml: function(){ return h; },
          text: function(){
            return h
              .replace(/<script[\s\S]*?<\/script>/gi, '')
              .replace(/<style[\s\S]*?<\/style>/gi, '')
              .replace(/<[^>]+>/g, ' ')
              .replace(/&nbsp;/g, ' ')
              .replace(/\s+/g, ' ')
              .trim();
          },
          title: function(){
            var m = h.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
            return m ? m[1].trim() : '';
          },
          select: function(){ return []; }
        };
      }
    }
  }
};
1
''');
      if (init.isError) {
        if (kDebugMode) {
          debugPrint('[JsEngine] init error: ${init.stringResult}');
        }
      }
      return _rt;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[JsEngine] runtime unavailable: $e');
      }
      _failed = true;
      return null;
    }
  }

  /// Install Legado `jsLib` helpers for the active source (idempotent per text).
  void ensureJsLib(String jsLib) {
    final lib = jsLib.trim();
    if (lib.isEmpty || lib == _loadedJsLib) return;
    final rt = _runtime;
    if (rt == null) return;
    try {
      rt.evaluate(lib);
      _loadedJsLib = lib;
      if (kDebugMode) {
        debugPrint('[JsEngine] jsLib loaded (${lib.length} chars)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[JsEngine] jsLib failed: $e');
      }
    }
  }

  /// `java.ajax` 两阶段 · 阶段 A：把 `java.ajax` 换成"记录调用 + 返回空串"的桩，
  /// 跑一遍 JS，拿到脚本尝试请求的 `url,{options}` 列表。
  ///
  /// 源常写 `a = java.ajax(url, opts); b = a.match(/…/)`，所以这一遍的产出
  /// 通常为空——调用方拿 [ajax] 里的 URL 用 Dart 侧网络栈抓下来，再交给
  /// [evalWithAjaxResponses] 重跑取最终地址。
  ({String out, List<String> ajax}) evalRecordingAjax(
    String code, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    final rt = _runtime;
    if (rt == null) {
      return (
        out: eval(
          code,
          result: result,
          baseUrl: baseUrl,
          src: src,
          jsLib: jsLib,
        ),
        ajax: const <String>[],
      );
    }
    try {
      rt.evaluate(
        'java.__ajaxCalls = [];'
        'java.ajax = function(u){'
        ' java.__ajaxCalls.push(String(u == null ? "" : u)); return ""; };',
      );
      final out = eval(
        code,
        result: result,
        baseUrl: baseUrl,
        src: src,
        jsLib: jsLib,
      );
      final raw = rt.evaluate('JSON.stringify(java.__ajaxCalls)').stringResult;
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      final calls = decoded is List
          ? decoded.map((e) => e.toString()).toList(growable: false)
          : const <String>[];
      return (out: out, ajax: calls);
    } catch (e) {
      if (kDebugMode) debugPrint('[JsEngine] ajax record failed: $e');
      return (out: '', ajax: const <String>[]);
    }
  }

  /// `java.ajax` 两阶段 · 阶段 B：把阶段 A 抓到的响应按 `url` 注入，
  /// `java.ajax` 变成查表函数，再跑一遍 JS 取最终结果。
  ///
  /// 未命中的 URL 仍会被记录进 `java.__ajaxCalls`，方便调用方补抓一轮。
  String evalWithAjaxResponses(
    String code,
    Map<String, String> responses, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    final rt = _runtime;
    if (rt == null) {
      return eval(
        code,
        result: result,
        baseUrl: baseUrl,
        src: src,
        jsLib: jsLib,
      );
    }
    try {
      rt.evaluate(
        'java.__ajaxResponses = ${jsonEncode(responses)};'
        'java.ajax = function(u){'
        ' var k = String(u == null ? "" : u);'
        ' if (java.__ajaxResponses[k] != null) return java.__ajaxResponses[k];'
        ' java.__ajaxCalls.push(k); return ""; };',
      );
      return eval(
        code,
        result: result,
        baseUrl: baseUrl,
        src: src,
        jsLib: jsLib,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[JsEngine] ajax inject failed: $e');
      return '';
    }
  }

  String _boundSourceKey = '';

  /// Legado 的 `source` 绑定：`source.getKey()` / `source.bookSourceUrl`
  /// 都等于书源的 `bookSourceUrl`，很多 `@js:` 搜索地址靠它拼出来
  /// （例如 `let ul = source.getKey() + "/search.html"`）。
  ///
  /// 每个源只注入一次；`source.getVariable()` 暂无变量字段可读，返回空串。
  void ensureSource({required String bookSourceUrl}) {
    if (bookSourceUrl.isEmpty || bookSourceUrl == _boundSourceKey) return;
    final rt = _runtime;
    if (rt == null) return;
    try {
      final key = jsonEncode(bookSourceUrl);
      rt.evaluate(
        'source.bookSourceUrl = $key;'
        'source.getKey = function(){ return $key; };'
        'source.getVariable = function(){ return ""; };'
        'source.getVariable2 = source.getVariable;',
      );
      _boundSourceKey = bookSourceUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('[JsEngine] source bind failed: $e');
    }
  }

  /// True if [rule] looks like it needs JS evaluation.
  static bool needsJs(String rule) {
    final r = rule.trim();
    if (r.isEmpty) return false;
    return r.startsWith('@js:') || r.contains('<js>') || r.contains('@js:');
  }

  /// Extract pure JS code from a Legado rule fragment.
  static String? extractCode(String rule) {
    final r = rule.trim();
    if (r.isEmpty) return null;
    if (r.startsWith('@js:')) {
      return r.substring(4).trim();
    }
    final m = RegExp(
      r'<js>([\s\S]*?)</js>',
      caseSensitive: false,
    ).firstMatch(r);
    if (m != null) return (m.group(1) ?? '').trim();
    // inline @js: mid-string
    final idx = r.indexOf('@js:');
    if (idx >= 0) return r.substring(idx + 4).trim();
    return null;
  }

  /// Evaluate [code] with bindings. Returns stringified result (JSON for list/map).
  String eval(
    String code, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    if (jsLib.isNotEmpty) ensureJsLib(jsLib);
    final rt = _runtime;
    if (rt == null || code.isEmpty) return result;
    try {
      // Escape via JSON so quotes/newlines are safe.
      final prelude =
          '''
var result = ${jsonEncode(result)};
var baseUrl = ${jsonEncode(baseUrl)};
var src = ${jsonEncode(src.isEmpty ? result : src)};
var java = java || {
  getString: function(x){ return String(x==null?'':x); },
  ajax: function(){ return ''; },
  longToast: function(){},
  startBrowserAwait: function(url, title){
    return { body: function(){ return ''; }, url: String(url||'') };
  }
};
if (typeof getArguments !== 'function') {
  function getArguments(vars, key) {
    if (vars == null || key == null) return '';
    var s = String(vars);
    var k = String(key);
    try {
      var o = JSON.parse(s);
      if (o && o[k] != null) return String(o[k]);
    } catch (e) {}
    var re = new RegExp('(?:^|[,;&\\\\s])' + k.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\\$&') + '=([^,;&\\\\s]*)');
    var m = s.match(re);
    if (m) {
      try { return decodeURIComponent(m[1]); } catch (e2) { return m[1]; }
    }
    return '';
  }
}
var source = {
  getVariable: function(){ return ''; },
  getKey: function(){ return baseUrl; },
  bookSourceUrl: baseUrl
};
if (typeof cfCheck !== 'function') {
  function cfCheck(html, targetUrl){ return String(html==null?'':html); }
}
''';
      // Bare expressions (Legado `@js: baseUrl.endsWith(...) ? …`) need `return (…)`.
      // Single expression-statements (`cfCheck(result, baseUrl);`) also need return.
      // Multi-statement scripts run as-is (should assign `result` if they need output).
      final trimmedCode = code.trim();
      final singleExprStmt = RegExp(
        r'^([^;{}\n]+);\s*$',
      ).firstMatch(trimmedCode);
      final looksExpr =
          !trimmedCode.contains(';') &&
          !trimmedCode.contains('{') &&
          !RegExp(
            r'\b(var|let|const|function|return|if|for|while|class)\b',
          ).hasMatch(trimmedCode);
      final String wrapped;
      if (looksExpr) {
        wrapped =
            '''
(function(){
$prelude
return ($trimmedCode);
})()
''';
      } else if (singleExprStmt != null) {
        final expr = singleExprStmt.group(1)!.trim();
        wrapped =
            '''
(function(){
$prelude
return ($expr);
})()
''';
      } else {
        wrapped =
            '''
(function(){
$prelude
$trimmedCode
return (typeof result === 'undefined' || result === null) ? '' : result;
})()
''';
      }
      final jsResult = rt.evaluate(wrapped);
      if (jsResult.isError) {
        if (kDebugMode) {
          debugPrint(
            '[JsEngine] eval error: ${jsResult.stringResult} '
            'code=${code.length > 80 ? '${code.substring(0, 80)}…' : code}',
          );
        }
        return result;
      }
      return _stringify(jsResult.stringResult, jsResult.rawResult);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[JsEngine] eval exception: $e');
      }
      return result;
    }
  }

  /// If [rule] is JS, run it against [input]; otherwise return null (caller handles).
  String? tryEvalRule(
    String rule, {
    required String input,
    required String baseUrl,
    String jsLib = '',
  }) {
    if (!needsJs(rule)) return null;
    final code = extractCode(rule);
    if (code == null || code.isEmpty) return null;
    return eval(
      code,
      result: input,
      baseUrl: baseUrl,
      src: input,
      jsLib: jsLib,
    );
  }

  /// Parse JS list output into List (of Map or String).
  List<dynamic> evalList(
    String code, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    final out = eval(
      code,
      result: result,
      baseUrl: baseUrl,
      src: src,
      jsLib: jsLib,
    );
    if (out.isEmpty) return const [];
    try {
      final decoded = jsonDecode(out);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } catch (_) {
      // newline / comma separated fallback
      final lines = out
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.length > 1) return lines;
    }
    return [out];
  }

  String _stringify(String stringResult, dynamic raw) {
    if (raw is List || raw is Map) {
      try {
        return jsonEncode(raw);
      } catch (_) {}
    }
    final s = stringResult;
    // QuickJS may return [object Object]; prefer JSON if looks like array
    if (s == '[object Object]' || s == 'undefined' || s == 'null') {
      try {
        return jsonEncode(raw);
      } catch (_) {
        return '';
      }
    }
    return s;
  }

  void dispose() {
    try {
      _rt?.dispose();
    } catch (_) {}
    _rt = null;
    _loadedJsLib = '';
  }
}
