# 离线回放样本（live fixtures）

把真实书源页面存到这里，写**不联网**的回归测试：以后每修一类书源能力，
就先加一条样本，再改代码，避免"修好这个源、弄坏那个源"。

## 文件格式（一个源一条 `.json`）

```json
{
  "name": "中文万维 · 搜索",
  "comment": "可选：来源站点、抓取时间、为什么存它",
  "source": { "bookSourceUrl": "http://cread.com", "ruleSearch": { "...": "..." } },
  "baseUrl": "https://cxb-pro.cread.com",
  "body": "<页面原文：HTML 或 JSON 字符串>",
  "isJson": true,
  "kind": "search",
  "expect": {
    "listCount": 1,
    "names": ["斗破苍穹之大世界"],
    "urls": ["https://readbook-service-freebook.cread.com/cx/bookDetailYS?bookid=803201785"]
  }
}
```

- `kind`: 目前支持 `search`（`ruleSearch.bookList` + name/bookUrl 规则）。
- `expect` 里的字段按需给：只校验写了的字段。
- `body` 直接内嵌字符串；很大的页面可以拆成同目录的 `.html` 文件，用
  `"bodyFile": "xxx.html"` 代替 `body`。

## 怎么采集

1. 手机上复现失败，把 logcat 里该源的 URL 抄下来；
2. 电脑上 `Invoke-WebRequest <url>` 存原文；
3. 连同该源的 JSON（书源管理 → 导出）一起做成一条样本。

回放测试见 `test/tools/fixture_replay_test.dart`，正常测试套件里会跑（无样本时跳过）。
