# 目录与模块

## 当前结构

Phase 1 已按功能重排 `lib/`，新代码优先落在对应 `features/` 目录。

```text
Novel/
├─ android/                 Android 壳、签名配置、MainActivity
├─ assets/
│  ├─ brand/                图标、启动图形源文件
│  └─ fonts/                随包字体与许可
├─ lib/
│  ├─ main.dart             入口
│  ├─ app/
│  │  ├─ bootstrap.dart     启动装配
│  │  ├─ providers.dart     Riverpod 装配
│  │  ├─ router/            Fluro 路由
│  │  └─ shell/             MainShell、底部 Dock、页头配置
│  ├─ core/
│  │  ├─ cache/             缓存管理
│  │  ├─ database/          SQLite（reader.db）
│  │  ├─ events/            EventBus 事件
│  │  ├─ network/           Dio 与拦截器
│  │  ├─ platform/          屏幕与系统 UI
│  │  ├─ storage/           本地键值存储
│  │  └─ utils/             日志等工具
│  ├─ data/
│  │  ├─ entities/          Book、Chapter、SearchItem 等
│  │  └─ repositories/      书、章节、书源的持久化
│  ├─ design/
│  │  ├─ brand/             应用名与固定文案
│  │  ├─ components/        PageHeader、搜索、立体书架、封面等展示组件
│  │  ├─ theme/             12 套主题、明暗控制
│  │  └─ tokens/            基础中性色、尺寸、阴影、字体与 ThemeData
│  └─ features/
│     ├─ shelf/             书架
│     ├─ discover/          发现
│     ├─ search/            搜索与按书合并
│     ├─ local/             本地 TXT 导入与本地书库
│     ├─ detail/            详情与换源
│     ├─ reader/            阅读器（分页、翻页、设置、缓存）
│     ├─ profile/           我的
│     ├─ settings/          皮肤、字体、缓存、日志
│     └─ sources/           书源模型、导入、仓库、规则引擎
├─ native/book_pager/       Rust 分页库源码
├─ third_party/flutter_js/  本地补丁的 JS 运行时
├─ test/                    Dart/Flutter 测试
├─ tool/                    品牌图生成等开发脚本
├─ docs/                    架构、路线、品牌、书源仓库、上游说明
├─ 备份/                    本地备份，不入库
├─ AGENTS.md                项目约定
├─ NOTICE                   上游归属
└─ LICENSE                  Apache-2.0
```

## 模块边界

- `app/shell/` 只负责四个主页签（书架 / 发现 / 本地 / 我）与 Dock 的装配，不承载业务逻辑。搜索不是页签，从书架 / 发现页头进入 `/search`。
- `design/tokens/` 只放中性色、尺寸、阴影、字体与 `buildLanghuanTheme`，不依赖业务状态。
- `design/theme/theme_presets.dart` 定义 12 套双色主题；`ColorModel` 只负责选择、持久化和构建 ThemeData。
- `design/components/` 只做展示：`PageHeader`、`PaperSearchEntry`、`Bookshelf3D`。
- `features/*/` 页面负责展示与交互，模型负责状态与调用；页面不直接写 SQL。
- `data/repositories/` 是数据库访问边界；书源列表查询不携带 `raw_json`，避免大 payload 过 MethodChannel。
- `features/sources/engine/` 只执行书源规则，不依赖 UI。
- `features/sources/repo/` 只负责把用户给的 URL 抓成 `SourceParseResult`，不内置地址。
- 阅读器分页核心在 `features/reader/page_content_reader.dart` 与 `features/reader/pagination/text_composition.dart`；Phase 1 没有改动其算法，后续视觉改造也不得触碰。
- 阅读器正文颜色由 `ReadSetting` 的纸色决定，不跟随 `ThemeData`，避免换肤影响正在阅读的文本。

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

搜索
  → SearchModel
  → SourceRepository.getEnabled()（只取元数据）
  → 每 8 个书源取一次完整规则
  → BookSourceEngine.search
  → 按「书名 + 作者」合并为 SearchGroup，标出书源数量

本地 TXT
  → FilePicker（仅 .txt）
  → TxtBookParser（UTF-8 / GBK、书名作者、章节标题）
  → LocalImportService
  → books / chapters（source_url = local://txt，正文已写入）
  → Reader（跳过书源与远程目录，直接读本地章节）
```

## 设计系统

- 页面固定白 / 黑底；12 套双色主题只切换强调色与辅助色。强调色会做对比度校正，亮黄 / 荧光色不整页铺底。
- 默认主题「鸢尾蓝 · 流光白」；主题定义在 `design/theme/theme_presets.dart`。
- 每页只保留一行 `PageHeader`，不保留品牌顶栏、英文副题和档案编号；底部为白底四页签 Dock，不使用胶囊。
- 发现页使用 `design/components/bookshelf_3d.dart`：书脊、书页厚度、透视、落地阴影与吸附翻页。
- 不使用重模糊；header / dock 都是实色白。
- 布局/主题测试在 `test/design/chrome_layout_test.dart`、`bookshelf_layout_test.dart` 与 `theme_preset_test.dart`，覆盖 360 / 411 / 800 宽、明暗两套、1.3 倍文字缩放与主题可读性。

## 数据库

- 单文件 `reader.db`，表：`books`、`chapters`、`sources`。
- 本地 TXT 复用现有 `books` / `chapters`，不新增表；`source_url` 以 `local://` 开头，章节正文直接存入 `chapters.body`。
- 上游的 `onUpgrade` 会清空所有表，这是数据丢失风险；Phase 4 必须先改成增量迁移。
- 任何 schema 改动前，先导出/备份数据库，并补迁移测试。
- 书签、阅读记录依赖新的表和迁移方案，必须等 Phase 4 增量迁移完成后再实现；Phase 1 没有新增表。

## 验证

- `flutter analyze`：通过。
- `flutter test`：77 项通过，其中设计/主题 14 项。
- debug arm64 APK：可构建。
- Phase 1 真机验收：待补测（构建产物 `build/app/outputs/flutter-apk/app-debug.apk`）。
