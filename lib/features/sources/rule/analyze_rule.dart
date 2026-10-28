import 'dart:convert';

import 'package:langhuan/features/sources/analyzer/css_analyzer.dart';
import 'package:langhuan/features/sources/analyzer/json_analyzer.dart';
import 'package:langhuan/features/sources/analyzer/js_analyzer.dart';
import 'package:langhuan/features/sources/analyzer/regex_analyzer.dart';
import 'package:langhuan/features/sources/analyzer/xpath_analyzer.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';
import 'package:html/dom.dart';

/// Dispatches a Legado-style rule string against HTML or JSON content.
class AnalyzeRule {
  final String content;
  final String baseUrl;
  final bool isJson;

  /// Optional Legado jsLib helpers for this evaluation.
  final String jsLib;
  Document? _doc;
  dynamic _json;

  AnalyzeRule({
    required this.content,
    required this.baseUrl,
    bool? isJson,
    this.jsLib = '',
  }) : isJson = isJson ?? _detectJson(content) {
    if (jsLib.isNotEmpty) {
      JsEngine.instance.ensureJsLib(jsLib);
    }
  }

  static bool _detectJson(String c) {
    final t = c.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  Document get doc => _doc ??= CssAnalyzer.parse(content);

  dynamic get jsonRoot {
    _json ??= () {
      try {
        return jsonDecode(content);
      } catch (_) {
        return null;
      }
    }();
    return _json;
  }

  /// Get a list of elements/nodes for list rules (bookList / chapterList).
  /// Supports `||` alternatives: first non-empty wins.
  List<dynamic> getList(String rule) {
    if (rule.isEmpty) return const [];

    for (final alt in _splitAlternatives(rule)) {
      final list = _getListSingle(alt);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  List<dynamic> _getListSingle(String rule) {
    if (rule.isEmpty) return const [];

    // Prefix JS transform then CSS/XPath list:
    //   <js>cfCheck(result, baseUrl);</js>#catalog ul a[-1:0]
    final hybrid = _splitLeadingJs(rule);
    if (hybrid != null) {
      final transformed = JsEngine.instance.eval(
        hybrid.js,
        result: content,
        baseUrl: baseUrl,
        src: content,
      );
      final tail = hybrid.tail.trim();
      if (tail.isEmpty) {
        return JsEngine.instance.evalList(
          hybrid.js,
          result: content,
          baseUrl: baseUrl,
          src: content,
          jsLib: jsLib,
        );
      }
      // Re-run list rule against transformed body.
      return AnalyzeRule(
        content: transformed.isEmpty ? content : transformed,
        baseUrl: baseUrl,
        isJson: _detectJson(transformed),
        jsLib: jsLib,
      )._getListSingle(tail);
    }

    // Pure JS list rule
    if (JsEngine.needsJs(rule) && !_hasTrailingCssAfterJs(rule)) {
      final code = JsEngine.extractCode(rule);
      if (code != null && code.isNotEmpty) {
        return JsEngine.instance.evalList(
          code,
          result: content,
          baseUrl: baseUrl,
          src: content,
          jsLib: jsLib,
        );
      }
    }

    final parsed = _parseRule(rule);
    if (parsed.kind == _RuleKind.js) {
      return JsEngine.instance.evalList(
        parsed.selector,
        result: content,
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
    }
    if (parsed.kind == _RuleKind.xpath) {
      return XpathAnalyzer.getList(doc, parsed.selector);
    }
    if (parsed.kind == _RuleKind.json || isJson) {
      return JsonAnalyzer.getList(jsonRoot, parsed.selector);
    }
    if (parsed.kind == _RuleKind.regex) {
      return RegexAnalyzer.getList(content, parsed.selector);
    }
    // CSS / Jsoup-normalized default
    return CssAnalyzer.getElements(doc, parsed.selector);
  }

  /// Extract a single string from [scope] (Element, Map, String, or full content).
  ///
  /// Supports:
  /// - `||` alternatives: first non-empty wins
  /// - `&&` field join: non-empty parts joined with space (outside JS / ##)
  String getString(String rule, {dynamic scope}) {
    if (rule.isEmpty) return '';

    // `&&` multi-part join (Legado): kind = "label.1@text&&label.2@text"
    if (_hasJoin(rule)) {
      final parts = _splitJoin(rule);
      final out = <String>[];
      for (final p in parts) {
        final v = getString(p, scope: scope);
        if (v.isNotEmpty) out.add(v);
      }
      return out.join(' ').trim();
    }

    for (final alt in _splitAlternatives(rule)) {
      final v = _getStringSingle(alt, scope: scope);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _getStringSingle(String rule, {dynamic scope}) {
    if (rule.isEmpty) return '';

    // All-in-one: rule##regex##replace  (but not inside JS code)
    var r = rule;
    String? postRegex;
    String? postReplace;
    if (!JsEngine.needsJs(r) && r.contains('##')) {
      // Only top-level `##` separates rule / regex / replacement; `##` inside
      // `{{...}}` belongs to the inner rule (Legado template syntax).
      final first = _indexOfTopLevel(r, '##');
      if (first >= 0) {
        final head = r.substring(0, first);
        final rest = r.substring(first + 2);
        final second = _indexOfTopLevel(rest, '##');
        r = head;
        if (second >= 0) {
          postRegex = rest.substring(0, second);
          postReplace = rest.substring(second + 2);
        } else {
          postRegex = rest;
        }
      }
    }

    // Legado template syntax: `{{rule}}` interpolation and `{rule}` optional
    // segments. Only for non-JS rules — JS code uses braces for blocks.
    if (!_containsJsMarker(r) && r.contains('{')) {
      var templated = _interpolateTemplate(r, scope: scope);
      if (postRegex != null && postRegex.isNotEmpty) {
        templated = _applyPost(templated, postRegex, postReplace);
      }
      return templated.trim();
    }

    // Trailing JS transform: `selector@attr@js:code`.
    // Legado applies the code to the value the head rule extracted, e.g.
    //   @onclick@js:result.match(/\('(.*?)', '', ''\)/)[1]
    // This must run before the pure-JS branch below, which would otherwise
    // evaluate the code against the whole element text.
    final trailingJs = _splitTrailingJs(r);
    if (trailingJs != null) {
      final prior = trailingJs.head.isEmpty
          ? _scopeToText(scope)
          : getString(trailingJs.head, scope: scope);
      var result = JsEngine.instance.eval(
        trailingJs.code,
        result: prior,
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
      if (postRegex != null && postRegex.isNotEmpty) {
        result = _applyPost(result, postRegex, postReplace);
      }
      return result.trim();
    }

    // Prefix JS then CSS/attr:
    //   <js>cfCheck(result, baseUrl);</js>.txtnav@textNodes
    final hybrid = _splitLeadingJs(r);
    if (hybrid != null) {
      final input = _scopeToText(scope);
      final transformed = JsEngine.instance.eval(
        hybrid.js,
        result: input.isEmpty ? content : input,
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
      final tail = hybrid.tail.trim();
      String result;
      if (tail.isEmpty) {
        result = transformed;
      } else {
        result = AnalyzeRule(
          content: transformed.isEmpty ? content : transformed,
          baseUrl: baseUrl,
          isJson: _detectJson(transformed),
          jsLib: jsLib,
        ).getString(tail);
      }
      if (postRegex != null && postRegex.isNotEmpty) {
        result = _applyPost(result, postRegex, postReplace);
      }
      return result.trim();
    }

    // Pure JS rule on full content / prior result
    if (JsEngine.needsJs(r)) {
      final input = _scopeToText(scope);
      final code = JsEngine.extractCode(r) ?? '';
      var result = JsEngine.instance.eval(
        code,
        result: input.isEmpty ? content : input,
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
      if (postRegex != null && postRegex.isNotEmpty) {
        result = _applyPost(result, postRegex, postReplace);
      }
      return result.trim();
    }

    // Hybrid: CSS/JSON first then trailing <js>
    final jsEmbed = RegExp(
      r'([\s\S]*?)<js>([\s\S]*?)</js>\s*$',
      caseSensitive: false,
    ).firstMatch(r);
    if (jsEmbed != null) {
      final head = (jsEmbed.group(1) ?? '').trim();
      final code = (jsEmbed.group(2) ?? '').trim();
      String prior = '';
      if (head.isNotEmpty) {
        prior = getString(head, scope: scope);
      } else {
        prior = _scopeToText(scope);
        if (prior.isEmpty) prior = content;
      }
      return JsEngine.instance
          .eval(
            code,
            result: prior,
            baseUrl: baseUrl,
            src: content,
            jsLib: jsLib,
          )
          .trim();
    }

    final parsed = _parseRule(r);
    String result = '';

    if (parsed.kind == _RuleKind.js) {
      result = JsEngine.instance.eval(
        parsed.selector,
        result: _scopeToText(scope).isEmpty ? content : _scopeToText(scope),
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
    } else if (parsed.kind == _RuleKind.xpath) {
      if (scope is Element) {
        // Scope element: wrap as fragment document.
        final frag = CssAnalyzer.parse(scope.outerHtml);
        result = XpathAnalyzer.getString(frag, parsed.selector);
      } else {
        result = XpathAnalyzer.getString(doc, parsed.selector);
      }
    } else if (scope is Element) {
      result = CssAnalyzer.getString(scope, parsed.selector, parsed.attr);
      // Bare attr on current element already handled (empty selector).
      // If a *child* selector missed:
      // - recover href/src from nested <a>/<img> (common toc/list rules)
      // - do NOT fall back to scope.text for text/ownText — that dumps the
      //   whole list-item (title+author+intro) and poisons author/name fields.
      if (result.isEmpty && parsed.selector.isNotEmpty) {
        if (parsed.attr == 'href' || parsed.attr == 'src') {
          final a = scope.localName == 'a' ? scope : scope.querySelector('a');
          if (a != null) {
            result = a.attributes[parsed.attr] ?? '';
          }
        }
      }
    } else if (scope is Map || scope is List || (isJson && scope == null)) {
      final root = scope ?? jsonRoot;
      result = JsonAnalyzer.getString(root, parsed.selector);
    } else if (parsed.kind == _RuleKind.regex) {
      final text = scope is String ? scope : content;
      result = RegexAnalyzer.getString(text, parsed.selector);
    } else if (parsed.kind == _RuleKind.json || isJson) {
      result = JsonAnalyzer.getString(scope ?? jsonRoot, parsed.selector);
    } else {
      // CSS from full doc or sub-element string
      if (scope is String && scope.isNotEmpty) {
        final sub = CssAnalyzer.parse(scope);
        final els = CssAnalyzer.getElements(sub, parsed.selector);
        if (els.isNotEmpty) {
          result = CssAnalyzer.getString(els.first, '', parsed.attr);
        } else {
          result = CssAnalyzer.getString(
            sub.documentElement ?? sub.body!,
            '',
            parsed.attr,
          );
        }
      } else {
        final els = CssAnalyzer.getElements(doc, parsed.selector);
        if (els.isNotEmpty) {
          result = CssAnalyzer.getString(els.first, '', parsed.attr);
        }
      }
    }

    if (postRegex != null && postRegex.isNotEmpty) {
      result = _applyPost(result, postRegex, postReplace);
    }
    return result.trim();
  }

  String _applyPost(String result, String postRegex, String? postReplace) {
    try {
      final re = RegExp(postRegex, multiLine: true, dotAll: true);
      final rep = postReplace ?? '';
      // `$1` / `\1` group references are not expanded by String.replaceAll.
      if (rep.contains(r'$') || rep.contains(r'\')) {
        return result.replaceAllMapped(re, (m) => _expandGroups(rep, m));
      }
      return result.replaceAll(re, rep);
    } catch (_) {
      return result;
    }
  }

  /// Expand Legado replacement group refs (`$1`, `\1`) against [m].
  static String _expandGroups(String rep, Match m) {
    return rep.replaceAllMapped(RegExp(r'\$(\d+)|\\(\d+)'), (g) {
      final i = int.tryParse(g.group(1) ?? g.group(2) ?? '');
      if (i == null || i < 0 || i > m.groupCount) return g.group(0)!;
      return m.group(i) ?? '';
    });
  }

  static bool _containsJsMarker(String rule) {
    final lower = rule.toLowerCase();
    return lower.contains('@js:') || lower.contains('<js>');
  }

  /// First occurrence of [needle] that is not inside `{...}` template braces.
  static int _indexOfTopLevel(String s, String needle) {
    var depth = 0;
    for (var i = 0; i + needle.length <= s.length; i++) {
      final ch = s[i];
      if (ch == '{') {
        depth++;
        continue;
      }
      if (ch == '}') {
        if (depth > 0) depth--;
        continue;
      }
      if (depth == 0 && s.startsWith(needle, i)) return i;
    }
    return -1;
  }

  /// Evaluate Legado `{{rule}}` interpolation and `{rule}` optional segments.
  ///
  /// Literal text outside the braces is kept verbatim, so URL templates like
  /// `https://host/detail?id={{$.id}}` produce the final URL directly.
  /// `{{}}` always substitutes (possibly empty); `{}` drops the segment when
  /// the inner rule yields nothing.
  String _interpolateTemplate(String rule, {dynamic scope}) {
    final out = StringBuffer();
    var i = 0;
    while (i < rule.length) {
      final open = rule.indexOf('{', i);
      if (open < 0) {
        out.write(rule.substring(i));
        break;
      }
      out.write(rule.substring(i, open));
      final double = open + 1 < rule.length && rule[open + 1] == '{';
      final contentStart = open + (double ? 2 : 1);
      final close = rule.indexOf(double ? '}}' : '}', contentStart);
      if (close < 0) {
        out.write(rule.substring(open));
        break;
      }
      final inner = rule.substring(contentStart, close).trim();
      final value = inner.isEmpty ? '' : getString(inner, scope: scope);
      if (double || value.isNotEmpty) out.write(value);
      i = close + (double ? 2 : 1);
    }
    return out.toString();
  }

  /// Content rule often wants HTML then plain text.
  String getHtmlString(String rule, {dynamic scope}) {
    if (rule.isEmpty) return '';

    // Prefix JS then CSS html:
    final hybrid = _splitLeadingJs(rule);
    if (hybrid != null) {
      final input = _scopeToText(scope);
      final transformed = JsEngine.instance.eval(
        hybrid.js,
        result: input.isEmpty ? content : input,
        baseUrl: baseUrl,
        src: content,
        jsLib: jsLib,
      );
      final tail = hybrid.tail.trim();
      if (tail.isEmpty) return transformed;
      return AnalyzeRule(
        content: transformed.isEmpty ? content : transformed,
        baseUrl: baseUrl,
        isJson: _detectJson(transformed),
        jsLib: jsLib,
      ).getHtmlString(tail);
    }

    if (JsEngine.needsJs(rule)) {
      return getString(rule, scope: scope);
    }
    for (final alt in _splitAlternatives(rule)) {
      final parsed = _parseRule(alt);
      if (parsed.kind == _RuleKind.xpath) {
        // XPath typically returns attr text; fall back to getString.
        final v = getString(alt, scope: scope);
        if (v.isNotEmpty) return v;
        continue;
      }
      if (scope is Element) {
        if (parsed.selector.isEmpty) {
          final v = scope.innerHtml;
          if (v.isNotEmpty) return v;
          continue;
        }
        final els = CssAnalyzer.getElementsFrom(scope, parsed.selector);
        if (els.isEmpty) continue;
        return els.map((e) => e.innerHtml).join('\n');
      }
      final els = CssAnalyzer.getElements(doc, parsed.selector);
      if (els.isEmpty) {
        final v = getString(alt, scope: scope);
        if (v.isNotEmpty) return v;
        continue;
      }
      return els.map((e) => e.innerHtml).join('\n');
    }
    return '';
  }

  String _scopeToText(dynamic scope) {
    if (scope == null) return '';
    if (scope is String) return scope;
    if (scope is Element) return scope.text;
    if (scope is Map || scope is List) {
      try {
        return jsonEncode(scope);
      } catch (_) {
        return scope.toString();
      }
    }
    return scope.toString();
  }

  /// Split leading `<js>...</js>` + optional trailing CSS/XPath.
  /// Returns null if rule is not of that shape.
  static ({String js, String tail})? _splitLeadingJs(String rule) {
    final r = rule.trim();
    final m = RegExp(
      r'^<js>([\s\S]*?)</js>([\s\S]*)$',
      caseSensitive: false,
    ).firstMatch(r);
    if (m == null) return null;
    return (js: (m.group(1) ?? '').trim(), tail: m.group(2) ?? '');
  }

  static bool _hasTrailingCssAfterJs(String rule) {
    final h = _splitLeadingJs(rule);
    return h != null && h.tail.trim().isNotEmpty;
  }

  /// Split `head@js:code` where the JS transforms the head's value.
  /// Returns null for a leading `@js:` rule or when no tail transform exists.
  static ({String head, String code})? _splitTrailingJs(String rule) {
    final r = rule.trim();
    if (r.isEmpty || r.startsWith('@js:')) return null;
    final idx = r.lastIndexOf('@js:');
    if (idx <= 0) return null;
    return (
      head: r.substring(0, idx).trim(),
      code: r.substring(idx + 4).trim(),
    );
  }

  /// True when rule uses `&&` join outside of JS / ## replace.
  static bool _hasJoin(String rule) {
    final r = rule.trim();
    if (!r.contains('&&')) return false;
    // `&&` inside a trailing @js: transform is a JS operator.
    if (_splitTrailingJs(r) != null) return false;
    if (JsEngine.needsJs(r) &&
        !_hasTrailingCssAfterJs(r) &&
        !r.contains('##')) {
      // Pure JS may contain && as operator — don't split.
      if (r.startsWith('@js:') || r.startsWith('<js>')) return false;
    }
    // Heuristic: field rules look like `a@text&&b@text` or `label.1@text&&…`
    return RegExp(r'&&').hasMatch(r) &&
        !r.trimLeft().startsWith('@js:') &&
        !(r.trimLeft().startsWith('<js>') && !_hasTrailingCssAfterJs(r));
  }

  static List<String> _splitJoin(String rule) {
    final out = splitTopLevel(rule, '&&');
    return out.isEmpty ? [rule] : out;
  }

  /// Split on a *top-level* separator, ignoring ones inside `[...]`, `(...)`
  /// or quotes — Legado's RuleAnalyzer does the same so JSONPath filters like
  /// `$[?(@.name=='a&&b')]` and attribute selectors like `[title="x||y"]`
  /// are not torn apart.
  static List<String> splitTopLevel(String rule, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    String? quote;
    for (var i = 0; i < rule.length; i++) {
      final ch = rule[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == r'\' && i + 1 < rule.length) {
          buf.write(rule[++i]);
        } else if (ch == quote) {
          quote = null;
        }
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '(' || ch == '[') depth++;
      if (ch == ')' && depth > 0) depth--;
      if (ch == ']' && depth > 0) depth--;
      if (depth == 0 && rule.startsWith(sep, i)) {
        final part = buf.toString().trim();
        if (part.isNotEmpty) out.add(part);
        buf.clear();
        i += sep.length - 1;
        continue;
      }
      buf.write(ch);
    }
    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out;
  }

  /// Split Legado `||` alternatives, ignoring `||` inside JS blocks.
  List<String> _splitAlternatives(String rule) {
    final r = rule.trim();
    if (r.isEmpty) return const [];
    if (!r.contains('||')) return [r];
    // `||` inside a trailing @js: transform is a JS operator, not an
    // alternative separator.
    if (_splitTrailingJs(r) != null) return [r];
    // Don't split pure JS or mid-JS ||.
    if (r.startsWith('@js:') ||
        (r.startsWith('<js>') && !_hasTrailingCssAfterJs(r))) {
      return [r];
    }
    // Without embedded JS the generic top-level splitter is enough (it also
    // protects `[...]` / `(...)` / quotes).
    if (!r.contains('<js>')) {
      final out = splitTopLevel(r, '||');
      return out.isEmpty ? [r] : out;
    }
    // Hybrid: only split the CSS tail after </js>
    final hybrid = _splitLeadingJs(r);
    if (hybrid != null && hybrid.tail.contains('||')) {
      // Alternatives apply to whole hybrid prefix+each alt? Legado usually puts
      // || outside. Keep simple: split full string only outside <js>.
    }
    // Split ignoring || that appear inside <js>...</js>
    final out = <String>[];
    final buf = StringBuffer();
    var inJs = false;
    for (var i = 0; i < r.length; i++) {
      if (!inJs &&
          i + 4 <= r.length &&
          r.substring(i, i + 4).toLowerCase() == '<js>') {
        inJs = true;
        buf.write(r.substring(i, i + 4));
        i += 3;
        continue;
      }
      if (inJs &&
          i + 5 <= r.length &&
          r.substring(i, i + 5).toLowerCase() == '</js>') {
        inJs = false;
        buf.write(r.substring(i, i + 5));
        i += 4;
        continue;
      }
      if (!inJs && i + 2 <= r.length && r.substring(i, i + 2) == '||') {
        final part = buf.toString().trim();
        if (part.isNotEmpty) out.add(part);
        buf.clear();
        i += 1;
        continue;
      }
      buf.write(r[i]);
    }
    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out.isEmpty ? [r] : out;
  }

  _ParsedRule _parseRule(String rule) {
    var r = rule.trim();
    if (r.startsWith('@js:')) {
      return _ParsedRule(_RuleKind.js, r.substring(4).trim(), '');
    }
    // @css: selector@attr
    if (r.startsWith('@css:')) {
      r = r.substring(5);
      return _splitAttr(r, _RuleKind.css);
    }
    if (r.startsWith('@json:') || r.startsWith('\$.') || r.startsWith('\$[')) {
      if (r.startsWith('@json:')) r = r.substring(6);
      return _ParsedRule(_RuleKind.json, r, '');
    }
    if (r.startsWith('@regex:') || r.startsWith(':')) {
      if (r.startsWith('@regex:')) r = r.substring(7);
      if (r.startsWith(':')) r = r.substring(1);
      return _ParsedRule(_RuleKind.regex, r, '');
    }
    if (r.startsWith('@xpath:') || r.startsWith('//') || r.startsWith('./')) {
      if (r.startsWith('@xpath:')) r = r.substring(7).trim();
      return _ParsedRule(_RuleKind.xpath, r, '');
    }
    // Bare attribute on current element: text / href / @text / @href / data-xxx
    final bare = r.startsWith('@') ? r.substring(1) : r;
    if (_knownAttrs.contains(bare) || bare.startsWith('data-')) {
      // Keep textNodes / ownText distinct — CssAnalyzer implements them
      // differently from full descendant text.
      return _ParsedRule(isJson ? _RuleKind.json : _RuleKind.css, '', bare);
    }
    // Default CSS; allow trailing @text / @href / @src / @html / @data-xxx
    return _splitAttr(r, isJson ? _RuleKind.json : _RuleKind.css);
  }

  _ParsedRule _splitAttr(String r, _RuleKind kind) {
    // selector@href  or selector@text  (last segment only when it is an attr)
    final at = r.lastIndexOf('@');
    if (at > 0) {
      final attr = r.substring(at + 1).trim();
      // avoid treating email-like / tag.a as attr; common attrs only
      if (_knownAttrs.contains(attr) ||
          attr.startsWith('data-') ||
          attr == 'html') {
        return _ParsedRule(kind, r.substring(0, at).trim(), attr);
      }
    }
    return _ParsedRule(kind, r, '');
  }

  static const _knownAttrs = {
    'text',
    'href',
    'src',
    'html',
    'textNodes',
    'ownText',
    'content',
    'value',
    'alt',
    'title',
    'id',
    'class',
    // Many sites put the detail link in an inline handler:
    //   <a href="javascript:;" onclick="openBook('123','','')">…
    'onclick',
  };
}

enum _RuleKind { css, json, regex, js, xpath }

class _ParsedRule {
  final _RuleKind kind;
  final String selector;
  final String attr;
  _ParsedRule(this.kind, this.selector, this.attr);
}

/// Apply content replaceRegex after extraction.
String finalizeContent(String rawHtmlOrText, String replaceRegex) {
  var t = htmlToPlainText(rawHtmlOrText);
  t = applyReplaceRegex(t, replaceRegex);
  return normalizeChapterBody(t);
}
