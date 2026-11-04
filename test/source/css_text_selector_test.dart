import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/analyzer/css_analyzer.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';

/// Legado `text.xxx`（自身文字包含）与负索引 `a.-1` 的回归测试。
/// 真实书源里 26+ 个 `nextContentUrl` 依赖 `text.下一页@href` 翻页正文。
void main() {
  const html = '''
  <html><body>
    <div class="wrap"><a href="/book/1_1.html">上一页</a></div>
    <div class="wrap"><a href="/book/1_2.html">下一页</a></div>
    <div class="wrap"><a href="/book/1_3.html">下一章</a></div>
  </body></html>
  ''';

  test('text.下一页@href 命中自身文字包含的元素（不是外层容器）', () {
    final doc = CssAnalyzer.parse(html);
    final href = CssAnalyzer.getString(
      doc.documentElement!,
      'text.下一页',
      'href',
    );
    expect(href, '/book/1_2.html');
  });

  test('text:下一章@href 冒号写法与点号等价', () {
    final doc = CssAnalyzer.parse(html);
    final href = CssAnalyzer.getString(
      doc.documentElement!,
      'text:下一章',
      'href',
    );
    expect(href, '/book/1_3.html');
  });

  test('a.-1@href 取最后一个匹配（负索引）', () {
    final doc = CssAnalyzer.parse(html);
    final href = CssAnalyzer.getString(doc.documentElement!, 'a.-1', 'href');
    expect(href, '/book/1_3.html');
  });

  test('常规选择器不受影响', () {
    final doc = CssAnalyzer.parse(html);
    final href = CssAnalyzer.getString(doc.documentElement!, '.wrap a', 'href');
    expect(href, '/book/1_1.html');
  });

  test('@ 链与负索引组合：.pager@a.-1@href（野外 nextContentUrl 形态）', () {
    const pager = '''
    <div class="pager">
      <a href="/n/2.html">下一页</a>
      <a href="/n/9.html">尾页</a>
    </div>
    ''';
    final rule = AnalyzeRule(
      content: pager,
      baseUrl: 'https://example.com/n/1.html',
      isJson: false,
    );
    expect(rule.getString('.pager@a.-1@href'), '/n/9.html');
  });

  test('AnalyzeRule 完整链路：text.下一页@href（含 || 分支，nextContentUrl 形态）', () {
    final rule = AnalyzeRule(
      content: html,
      baseUrl: 'https://example.com/book/1_1.html',
      isJson: false,
    );
    expect(rule.getString('text.下一页@href'), '/book/1_2.html');
    expect(
      rule.getString('text.下一页@href||text.下一章@href'),
      '/book/1_2.html',
    );
  });
}
