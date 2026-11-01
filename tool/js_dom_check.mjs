// 宿主无 QuickJS 时，用 Node 验证 js_analyzer.dart 注入的 DOM/CSS 预处理脚本。
// 运行：E:\Node\node.exe tool/js_dom_check.mjs   （在仓库根目录）
// 只读提取 Dart 里的 init 预置脚本原文，在真实的 JS 引擎里跑断言。
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert';

const dart = fs.readFileSync('lib/features/sources/analyzer/js_analyzer.dart', 'utf8');
const m = dart.match(/final init = _rt!\.evaluate\(r'''([\s\S]*?)'''\);/);
assert.ok(m, 'js_analyzer.dart 里未找到 init 预置脚本');

const ctx = {};
vm.createContext(ctx);
vm.runInContext(m[1], ctx);

const doc = ctx.org.jsoup.Jsoup.parse(`<html><head><title> 测 试 </title></head><body>
  <div id="content" class="box main">
    <ul class="list">
      <li><a href="/a1"> 章节一 </a></li>
      <li><a href="/a2">章节二</a></li>
      <li class="last"><a href="/a3">章节三</a></li>
    </ul>
  </div>
  <script>var x = 1;</script>
</body></html>`);

// title / text / html
assert.strictEqual(doc.title(), '测 试');
assert.ok(!doc.text().includes('var x'), 'text() 不应包含 script 内容');
assert.ok(doc.html().includes('<ul class="list">'), '文档级 html() 返回原文');
assert.ok(doc.text().includes('章节三'));

// select：直接子级 + 后代 + 属性
const links = doc.select('ul.list > li a');
assert.strictEqual(links.size(), 3);
assert.strictEqual(links.get(0).text(), '章节一');
assert.strictEqual(links.first().attr('href'), '/a1');
assert.strictEqual(links.get(2).attr('href'), '/a3');
assert.strictEqual(doc.select('div#content a[href^=/a]').size(), 3);
assert.strictEqual(doc.select('#content .list li.last a').text(), '章节三');

// :eq / :first / :last
assert.strictEqual(doc.select('li:eq(1) a').text(), '章节二');
assert.strictEqual(doc.select('li:first a').text(), '章节一');
assert.strictEqual(doc.select('li:last a').text(), '章节三');

// Elements 级联：select 之后继续 select / html
const ul = doc.select('ul').first();
assert.ok(ul.html().includes('章节一'), '元素级 html()');
assert.strictEqual(ul.select('li a').size(), 3);

// 逗号并集 + 通配
assert.strictEqual(doc.select('title, li').size(), 4);
assert.ok(doc.select('*').size() > 5);

// document（惰性 DOM）
const d2 = ctx.__html.lazyDocument('<div><p id="p1">甲</p><p class="x">乙</p></div>');
assert.strictEqual(d2.querySelector('#p1').text(), '甲');
assert.strictEqual(d2.querySelectorAll('p').size(), 2);
assert.strictEqual(d2.getElementById('p1').text(), '甲');
assert.strictEqual(d2.querySelector('.nope'), null);
assert.strictEqual(d2.querySelectorAll('p.x').first().text(), '乙');

// 实体解码
const d3 = ctx.org.jsoup.Jsoup.parse('<p>a&amp;b&nbsp;c&#65;&#x42;</p>');
assert.strictEqual(d3.select('p').text(), 'a&b cAB');

// 未闭合标签容错
const d4 = ctx.org.jsoup.Jsoup.parse('<div><p>一<div><p>二');
assert.strictEqual(d4.select('p').size(), 2);

console.log('js_dom_check: all assertions passed');
