# 目录与模块

## 当前结构

```text
Novel/
├─ android/                 Android 壳、签名配置、MainActivity
├─ assets/
│  └─ fonts/                随包字体与许可
├─ lib/
│  ├─ animation/            仿真/覆盖等翻页动画
│  ├─ common/               设置、存储、颜色、日志、字体
│  ├─ data/
│  │  ├─ db/                SQLite（reader.db）
│  │  └─ repositories/      书、章节、书源的持久化
│  ├─ entity/               Book、Chapter 等数据实体
│  ├─ event/                EventBus 事件
│  ├─ model/                Riverpod/ChangeNotifier 状态模型
│  ├─ route/                Fluro 路由
│  ├─ service/              平台服务
│  ├─ source/
│  │  ├─ import/            书源 JSON 解析与导入
│  │  ├─ model/             BookSource 规则模型
│  │  ├─ repo/              私有书源仓库抓取
│  │  └─ engine/            书源规则执行
│  ├─ store/                Provider 装配
│  ├─ view/                 页面（书架/发现/阅读器/我的）
│  └─ widgets/              共享组件
├─ native/                  Rust book_pager 源码
├─ third_party/flutter_js/  本地补丁的 JS 运行时
├─ test/                    Dart/Flutter 测试
├─ docs/                    架构、路线、书源仓库、上游说明
├─ 备份/                    本地备份，不入库
├─ AGENTS.md                项目约定
├─ NOTICE                   上游归属
└─ LICENSE                  Apache-2.0
```

## 模块边界

- `view/` 只做展示与交互，不直接写 SQL。
- `model/` 聚合状态、调用 repository/service；页面通过 Provider 读状态。
- `data/repositories/` 是数据库访问边界；书源列表查询不携带 `raw_json`，避免大 payload 过 MethodChannel。
- `source/engine/` 只执行书源规则，不依赖 UI。
- `source/repo/` 只负责把用户给的 URL 抓成 `SourceParseResult`，不内置地址。
- 阅读器分页核心在 `view/book/page_content_reader.dart` 与 `common/text_composition.dart`；Phase 1–2 不改其算法。

## 数据流

```text
用户输入仓库 URL
  → SourceRepo.fetch(url)
  → SourceImporter.parseJson(text)
  → SourceModel.importParsed(...)
  → SourceRepository.upsert(...)
  → reader.db (sources)

书架打开书
  → BookRepository / ChapterRepository
  → SourceModel.enabledSources()
  → BookSourceEngine
  → 章节正文 / 目录
```

## 数据库

- 单文件 `reader.db`，表：`books`、`chapters`、`sources`。
- 上游的 `onUpgrade` 会清空所有表，这是数据丢失风险；Phase 4 必须先改成增量迁移。
- 任何 schema 改动前，先导出/备份数据库，并补迁移测试。
