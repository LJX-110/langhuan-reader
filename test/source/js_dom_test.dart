import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/analyzer/js_analyzer.dart';

/// JS `document` / `org.jsoup.Jsoup.parse(...).select(...)` 行为验证。
///
/// 宿主机没有 QuickJS 运行时 → 打印 SKIP；真机（或带 JS 运行时的宿主）
/// 会跑完整断言。宿主的替代验证：`node tool/js_dom_check.mjs`。
void main() {
  const html =
      '<div id="c"><a class="x" href="/a">甲</a><a href="/b">乙</a></div>';

  bool runtimeAvailable() {
    final probe = JsEngine.instance.eval("'ok'", result: '');
    return probe == 'ok';
  }

  test('document.querySelectorAll 与 getElementById', () {
    if (!runtimeAvailable()) {
      // ignore: avoid_print
      print('SKIP js_dom — JsEngine runtime unavailable in this test host');
      return;
    }
    expect(
      JsEngine.instance.eval("document.querySelectorAll('a.x').size()",
          result: html),
      '1',
    );
    expect(
      JsEngine.instance.eval("document.querySelector('a.x').text()",
          result: html),
      '甲',
    );
    expect(
      JsEngine.instance.eval("document.getElementById('c').select('a').size()",
          result: html),
      '2',
    );
    expect(
      JsEngine.instance.eval("document.querySelector('.nope')", result: html),
      'null',
    );
  });

  test('Jsoup.parse(...).select(...) 选择链', () {
    if (!runtimeAvailable()) {
      // ignore: avoid_print
      print('SKIP js_dom — JsEngine runtime unavailable in this test host');
      return;
    }
    expect(
      JsEngine.instance.eval(
          "org.jsoup.Jsoup.parse(result).select('a').last().text()",
          result: html),
      '乙',
    );
    expect(
      JsEngine.instance.eval(
          "org.jsoup.Jsoup.parse(result).select('#c a[href=/b]').attr('href')",
          result: html),
      '/b',
    );
    expect(
      JsEngine.instance.eval(
          "org.jsoup.Jsoup.parse(result).select('a').size()",
          result: html),
      '2',
    );
  });
}
