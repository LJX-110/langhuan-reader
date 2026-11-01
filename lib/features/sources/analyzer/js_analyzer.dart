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
/// - `result`   previous stage text / current content
/// - `baseUrl`  page url
/// - `src`      full page body (alias of result when not chained)
/// - `document` lazy DOM of `src`: querySelector/querySelectorAll/getElementById
/// - `java`     tiny helper object (stubs for CF / browser APIs)
/// - `org.jsoup.Jsoup.parse(html)` with real `.select(css)` (lightweight
///   DOM + CSS engine shared with `document`)
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

// ---- 轻量 HTML DOM + CSS 选择器 ----------------------------------------
// org.jsoup.Jsoup.parse(html).select(...) 与 JS `document` 共用这一棵树。
// 覆盖源常用：标签/#id/.class/[attr]/[attr=v]/后代/直接子级/逗号并集/
// :eq(n)/:first/:last，以及 Elements 的 size/get/first/last/text/attr/html。
var __html = (function(){
  var VOID = {area:1,base:1,br:1,col:1,embed:1,hr:1,img:1,input:1,link:1,meta:1,param:1,source:1,track:1,wbr:1};

  function decodeEnt(s){
    return String(s == null ? '' : s)
      .replace(/&#x([0-9a-fA-F]+);/g, function(_, h){ try { return String.fromCodePoint(parseInt(h, 16)); } catch (e) { return ''; } })
      .replace(/&#(\d+);/g, function(_, d){ try { return String.fromCodePoint(parseInt(d, 10)); } catch (e) { return ''; } })
      .replace(/&nbsp;/gi, ' ')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&apos;/gi, "'")
      .replace(/&#39;/g, "'")
      .replace(/&amp;/gi, '&');
  }

  function escapeAttr(s){
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  }

  function parseHtml(html){
    var src = String(html == null ? '' : html);
    var root = { tag: '#document', attrs: {}, children: [], parent: null };
    var stack = [root];
    var i = 0, n = src.length;
    function top(){ return stack[stack.length - 1]; }
    function addText(t){
      var text = decodeEnt(t);
      if (!text) return;
      var kids = top().children;
      var last = kids.length ? kids[kids.length - 1] : null;
      if (last && last.tag === '#text') { last.text += text; }
      else kids.push({ tag: '#text', text: text, parent: top() });
    }
    while (i < n) {
      var lt = src.indexOf('<', i);
      if (lt < 0) { addText(src.substring(i)); break; }
      if (lt > i) addText(src.substring(i, lt));
      if (src.substring(lt, lt + 4) === '<!--') {
        var endC = src.indexOf('-->', lt + 4);
        i = endC < 0 ? n : endC + 3;
        continue;
      }
      var c1 = src.charAt(lt + 1);
      if (c1 === '!' || c1 === '?') {
        var endD = src.indexOf('>', lt);
        i = endD < 0 ? n : endD + 1;
        continue;
      }
      var m = /^<\s*(\/?)\s*([a-zA-Z][a-zA-Z0-9:-]*)/.exec(src.substring(lt));
      if (!m) { addText('<'); i = lt + 1; continue; }
      var closing = m[1] === '/', tag = m[2].toLowerCase();
      var j = lt + m[0].length, quote = 0, gt = -1;
      for (; j < n; j++) {
        var ch = src.charAt(j);
        if (quote) { if (ch === quote) quote = 0; continue; }
        if (ch === '"' || ch === "'") { quote = ch; continue; }
        if (ch === '>') { gt = j; break; }
      }
      if (gt < 0) gt = n;
      var attrText = src.substring(lt + m[0].length, gt);
      var selfClose = /\/\s*$/.test(attrText);
      if (selfClose) attrText = attrText.replace(/\/\s*$/, '');
      i = gt + 1;
      if (closing) {
        for (var k = stack.length - 1; k > 0; k--) {
          if (stack[k].tag === tag) { stack.length = k; break; }
        }
        continue;
      }
      var el = { tag: tag, attrs: {}, children: [], parent: top() };
      var are = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g, am;
      while ((am = are.exec(attrText))) {
        var name = am[1].toLowerCase();
        var val = am[2] != null ? am[2] : am[3] != null ? am[3] : am[4] != null ? am[4] : '';
        el.attrs[name] = decodeEnt(val);
      }
      top().children.push(el);
      if (VOID[tag] || selfClose) continue;
      if (tag === 'script' || tag === 'style') {
        var closeRe = new RegExp('<\\/\\s*' + tag + '\\s*>', 'ig');
        closeRe.lastIndex = i;
        var cm = closeRe.exec(src);
        i = cm ? closeRe.lastIndex : n;
        continue;
      }
      stack.push(el);
    }
    return root;
  }

  function elementChildren(node){
    var out = [], kids = node && node.children ? node.children : [];
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].tag !== '#text') out.push(kids[i]);
    }
    return out;
  }

  function elText(node){
    var out = '';
    (function walk(nd){
      var kids = nd.children || [];
      for (var i = 0; i < kids.length; i++) {
        if (kids[i].tag === '#text') out += kids[i].text;
        else walk(kids[i]);
      }
    })(node);
    return out.replace(/\s+/g, ' ').trim();
  }

  function ownText(node){
    var out = '', kids = node.children || [];
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].tag === '#text') out += kids[i].text;
    }
    return out.replace(/\s+/g, ' ').trim();
  }

  function serialize(node){
    if (node.tag === '#text') return node.text;
    var out = '';
    if (node.tag !== '#document') {
      out += '<' + node.tag;
      for (var k in node.attrs) {
        if (Object.prototype.hasOwnProperty.call(node.attrs, k)) {
          out += ' ' + k + '="' + escapeAttr(node.attrs[k]) + '"';
        }
      }
      out += '>';
      if (VOID[node.tag]) return out;
    }
    var kids = node.children || [];
    for (var i = 0; i < kids.length; i++) out += serialize(kids[i]);
    if (node.tag !== '#document') out += '</' + node.tag + '>';
    return out;
  }

  function El(node){ this.node = node; }
  El.prototype.tagName = function(){ return this.node.tag == null ? '' : this.node.tag; };
  El.prototype.text = function(){ return elText(this.node); };
  El.prototype.ownText = function(){ return ownText(this.node); };
  El.prototype.html = function(){
    var out = '', kids = this.node.children || [];
    for (var i = 0; i < kids.length; i++) out += serialize(kids[i]);
    return out;
  };
  El.prototype.outerHtml = function(){ return serialize(this.node); };
  El.prototype.attr = function(name){
    var k = String(name == null ? '' : name).toLowerCase();
    var v = this.node.attrs ? this.node.attrs[k] : undefined;
    return v == null ? '' : String(v);
  };
  El.prototype.hasAttr = function(name){
    var k = String(name == null ? '' : name).toLowerCase();
    return !!(this.node.attrs && this.node.attrs[k] != null);
  };
  El.prototype.id = function(){ return this.attr('id'); };
  El.prototype.className = function(){ return this.attr('class'); };
  El.prototype.children = function(){ return makeElements(elementChildren(this.node)); };
  El.prototype.child = function(idx){ return this.children().get(idx); };
  El.prototype.get = function(idx){ return this.children().get(idx); };
  El.prototype.select = function(css){ return makeElements(selectNodes(css, this.node)); };

  function makeElements(list){
    var arr = [];
    for (var i = 0; i < list.length; i++) arr.push(new El(list[i]));
    arr.size = function(){ return arr.length; };
    arr.get = function(idx){ return (idx >= 0 && idx < arr.length) ? arr[idx] : null; };
    arr.first = function(){ return arr.length ? arr[0] : null; };
    arr.last = function(){ return arr.length ? arr[arr.length - 1] : null; };
    arr.isEmpty = function(){ return arr.length === 0; };
    arr.text = function(){
      var s = '';
      for (var i = 0; i < arr.length; i++) {
        var t = elText(arr[i].node);
        if (t) s += (s ? ' ' : '') + t;
      }
      return s;
    };
    arr.eachText = function(){
      var o = [];
      for (var i = 0; i < arr.length; i++) o.push(elText(arr[i].node));
      return o;
    };
    arr.attr = function(name){
      for (var i = 0; i < arr.length; i++) {
        var v = arr[i].attr(name);
        if (v !== '') return v;
      }
      return '';
    };
    arr.html = function(){
      var o = [];
      for (var i = 0; i < arr.length; i++) o.push(arr[i].html());
      return o.join('\n');
    };
    arr.select = function(css){
      var merged = [];
      for (var i = 0; i < arr.length; i++) merged = merged.concat(selectNodes(css, arr[i].node));
      return makeElements(merged);
    };
    return arr;
  }

  function parseCompound(tok){
    var c = { tag: null, tagSet: false, id: null, classes: [], attrs: [], eq: null, eqLast: false };
    var rest = String(tok);
    var re = /^([A-Za-z][A-Za-z0-9-]*|\*)|^#([A-Za-z0-9_-]+)|^\.([A-Za-z0-9_-]+)|^\[([^\]]*)\]|^:eq\((\d+)\)|^:first|^:last/;
    while (rest.length > 0) {
      var m = re.exec(rest);
      if (!m) return null;
      rest = rest.substring(m[0].length);
      if (m[0] === ':first') { c.eq = 0; continue; }
      if (m[0] === ':last') { c.eqLast = true; continue; }
      if (m[1]) {
        if (m[1] === '*') { c.tagSet = false; c.tag = null; }
        else { c.tag = m[1].toLowerCase(); c.tagSet = true; }
        continue;
      }
      if (m[2]) { c.id = m[2]; continue; }
      if (m[3]) { c.classes.push(m[3]); continue; }
      if (m[4] != null) {
        var am = /^([A-Za-z0-9_:-]+)\s*(?:([~^$*|]?=)\s*(?:"([^"]*)"|'([^']*)'|([\s\S]*)))?$/.exec(m[4].trim());
        if (!am) return null;
        c.attrs.push({
          name: am[1].toLowerCase(),
          op: am[2] || null,
          value: am[3] != null ? am[3] : am[4] != null ? am[4] : am[5] != null ? am[5] : ''
        });
        continue;
      }
      if (m[5] != null) { c.eq = parseInt(m[5], 10); continue; }
      return null;
    }
    return c;
  }

  function matchesEl(node, c){
    if (!node || node.tag === '#text' || node.tag === '#document') return false;
    if (c.tagSet && c.tag && node.tag !== c.tag) return false;
    if (c.id != null && node.attrs['id'] !== c.id) return false;
    if (c.classes.length) {
      var cls = node.attrs['class'];
      if (cls == null) return false;
      var parts = String(cls).split(/\s+/);
      for (var i = 0; i < c.classes.length; i++) {
        if (parts.indexOf(c.classes[i]) < 0) return false;
      }
    }
    for (var j = 0; j < c.attrs.length; j++) {
      var a = c.attrs[j];
      var v = node.attrs[a.name];
      if (v == null) return false;
      if (a.op == null) continue;
      var sv = String(v);
      if (a.op === '=') { if (sv !== a.value) return false; }
      else if (a.op === '*=') { if (sv.indexOf(a.value) < 0) return false; }
      else if (a.op === '^=') { if (sv.substring(0, a.value.length) !== a.value) return false; }
      else if (a.op === '$=') { if (sv.substring(sv.length - a.value.length) !== a.value) return false; }
      else if (a.op === '~=') { if ((' ' + sv + ' ').indexOf(' ' + a.value + ' ') < 0) return false; }
      else if (a.op === '|=') { if (!(sv === a.value || sv.substring(0, a.value.length + 1) === a.value + '-')) return false; }
    }
    return true;
  }

  function selectNodes(css, root){
    var out = [];
    var groups = String(css == null ? '' : css).split(',');
    for (var g = 0; g < groups.length; g++) {
      var raw = groups[g].replace(/\s*>\s*/g, ' > ').trim();
      if (!raw) continue;
      var toks = raw.split(/\s+/);
      var current = [root];
      var direct = false;
      for (var t = 0; t < toks.length; t++) {
        var tok = toks[t];
        if (tok === '>') { direct = true; continue; }
        if (tok === '+') { direct = false; continue; } // 相邻兄弟不支持：降级为后代
        var c = parseCompound(tok);
        if (!c) { current = []; break; }
        var next = [];
        for (var n = 0; n < current.length; n++) {
          var nd = current[n];
          var kids = elementChildren(nd);
          if (direct) {
            for (var k = 0; k < kids.length; k++) {
              if (matchesEl(kids[k], c)) next.push(kids[k]);
            }
          } else {
            (function walk(node){
              var cs = elementChildren(node);
              for (var z = 0; z < cs.length; z++) {
                if (matchesEl(cs[z], c)) next.push(cs[z]);
                walk(cs[z]);
              }
            })(nd);
          }
        }
        if (c.eqLast) { next = next.length ? [next[next.length - 1]] : []; }
        else if (c.eq !== null) { next = (c.eq >= 0 && c.eq < next.length) ? [next[c.eq]] : []; }
        current = next;
        direct = false;
        if (!current.length) break;
      }
      out = out.concat(current);
    }
    return out;
  }

  function lazyDocument(html){
    var root = null;
    function ensure(){
      if (!root) root = parseHtml(html);
      return root;
    }
    var doc = {
      querySelector: function(css){
        var r = selectNodes(css, ensure());
        return r.length ? new El(r[0]) : null;
      },
      querySelectorAll: function(css){ return makeElements(selectNodes(css, ensure())); },
      getElementById: function(id){ return doc.querySelector('#' + id); },
      title: function(){
        var t = selectNodes('title', ensure());
        return t.length ? elText(t[0]) : '';
      }
    };
    return doc;
  }

  return { parse: parseHtml, select: selectNodes, lazyDocument: lazyDocument, elText: elText, El: El };
})();

var org = {
  jsoup: {
    Jsoup: {
      parse: function(html){
        var h = String(html == null ? '' : html);
        var root = __html.parse(h);
        var el = new __html.El(root);
        // 兼容既有行为：文档级 html()/outerHtml() 返回原文（源常拿去再正则）。
        el.html = function(){ return h; };
        el.outerHtml = function(){ return h; };
        el.title = function(){
          var t = __html.select('title', root);
          return t.length ? __html.elText(t[0]) : '';
        };
        return el;
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
// 当前页面的惰性 DOM（首次查询才解析）：querySelector/All、getElementById。
var document = (typeof __html !== 'undefined') ? __html.lazyDocument(src) : null;
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
