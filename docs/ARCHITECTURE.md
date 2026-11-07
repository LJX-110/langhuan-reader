# 目录与模块

## 当前结构

`lib/` 已按功能重排，新代码优先落在对应 `features/` 目录。当前版本线 2.3.x；书源统一由 `engine/`（Legado 裁剪集 AAR）+ `SourceEngine` 提供，无第二套 Dart 引擎。

```text
langhuan/
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
│  │  ├─ net/               会话 Cookie 等网络基础设施
│  │  ├─ platform/          屏幕与系统 UI
│  │  ├─ storage/           本地键值存储
│  │  └─ utils/             日志等工具
│  ├─ data/
│  │  ├─ entities/          Book、Chapter、SearchItem 等
│  │  └─ repositories/      书、章节、书源的持久化
│  ├─ design/
│  │  ├─ brand/             应用名与固定文案
│  │  ├─ components/        PageHeader、搜索、ShelfBookView、立体书架、封面等展示组件
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
│     ├─ backup/            备份与恢复（gzip JSON，合并导入）
│     ├─ settings/          皮肤、字体、缓存、日志
│     └─ sources/           书源模型、导入、仓库、SourceEngine 适配
├─ native/book_pager/       Rust 分页库源码
├─ engine/                  阅读内核（Legado 裁剪集）+ facade AAR
├─ test/                    Dart/Flutter 测试
├─ tool/                    品牌图生成等开发脚本
├─ docs/                    架构、路线、品牌、书源仓库、上游说明
├─ AGENTS.md                项目约定
├─ NOTICE                   上游归属
└─ LICENSE                  GPL-3.0（上游 Apache-2.0 原文在 third_party/）
```

## 模块边界

- `app/shell/` 只负责四个主页签（书架 / 发现 / 本地 / 我）与 Dock 的装配，不承载业务逻辑。搜索不是页签，从书架 / 发现页头进入 `/search`。
- `design/tokens/` 只放中性色、尺寸、阴影、字体与 `buildLanghuanTheme`，不依赖业务状态。
- `design/theme/theme_presets.dart` 定义 12 套双色主题；`ColorModel` 只负责选择、持久化和构建 ThemeData。
- `design/components/` 只做展示：`PageHeader`、`PaperSearchEntry`、`ShelfBookView`、`Bookshelf3D`、`PicWidget`。`Bookshelf3D` 只依赖通用展示模型，书架页与本地页共用。
- `features/local/` 的读文件、解码、解析和指纹计算在后台 isolate 完成；`reader.db` 写入留在主 isolate，避免大文件冻结 UI。
- `features/sources/sync/` 与 `features/sources/import/source_import_conflict.dart` 只做同步决策：手动 JSON / URL 导入比对完整规则，仓库同步先判断 URL 是否已存在；两者都默认保留本地规则，用户二次确认后才覆盖。写入在单事务内完成，失败整批回滚。
- `design/components/Bookshelf3D` 只用于书架页与本地页的 3D 模式；发现页保持平面列表，不挂载 3D 书架。
- `features/*/` 页面负责展示与交互，模型负责状态与调用；页面不直接写 SQL。
- `data/repositories/` 是数据库访问边界；书源列表查询不携带 `raw_json`，避免大 payload 过 MethodChannel。
- `features/sources/engine/` 只做 MethodChannel 适配（`SourceEngine`），不包含规则解析、JS 或 HTTP，不依赖 UI。
- `features/sources/repo/` 只负责把用户给的 URL 抓成 `SourceParseResult`，不内置地址。
- 阅读器分页核心在 `features/reader/page_content_reader.dart` 与 `features/reader/pagination/text_composition.dart`；后续视觉改造不得触碰。
- 阅读器正文颜色由 `ReadSetting` 的纸色决定，不跟随 `ThemeData`，避免换肤影响正在阅读的文本。
- 阅读器浮层拆为 `features/reader/menu/`：顶栏、底栏、章节滑条、下载与设置面板；`reader_menu.dart` 只保留浮层编排与状态。
- 顶栏显示书名 + 当前章节名；排版设置的连续调整由 `ReaderContentReloader.scheduleRelayout()` 合并为一次重排，避免每次滑动都清缓存、重分页。
- 系统栏统一走 `SystemUiHelper.overlayStyle(context)`：透明状态栏 / 导航栏、按页面明暗切换图标色并关闭导航栏对比度遮罩；列表页与底部栏自行叠加 `viewPadding.bottom`，避免被系统导航条盖住。
- 书源请求统一走原生引擎（`engine/`）；Dart 层只负责合并、排序、诊断与缓存，不再直接发书源 HTTP 请求。
- 通道 `langhuan/engine` 使用 4 线程有界执行池（队列 64）：搜索 6 / 换源 12 / 体检 4 只是提交并发，**实际同时执行位为 4**；队列满返回 `engine_busy`，超时/取消回发 `cancel(requestId)`。
- 引擎日志经 EventChannel `langhuan/engine_log` 转发到应用日志页（标签 `Engine`）；原生侧保留最近 200 行，监听后补发。引擎非文本模块（漫画/tvbox/rss/webdav/tts/词典）仍随 AAR 编译，裁剪列入 2.4.0。

## 数据流

```text
用户输入仓库 URL
  → SourceRepo.fetch(url)
  → SourceImporter.parseJson(text)
  → SourceModel.inspectImport(...) / buildSourceSyncPlan(...)
  → 用户选择：默认保留本地规则，或明确覆盖
  → SourceRepository.upsertAllWithStats / overwriteAllWithRollback
  → 单事务写 reader.db (sources)，失败整批回滚
  → 重新加载书源列表

书架打开书
  → BookRepository / ChapterRepository
  → SourceModel.findByUrl()（完整规则）
  → SourceEngine.bookInfo / toc / content
  → 原生引擎返回章节正文 / 目录

搜索
  → SearchModel
  → SourceRepository.getEnabled()（只取元数据）
  → 每个书源取完整规则（并发 6）
  → SourceEngine.searchWithReport
  → 按「书名 + 作者」合并为 SearchGroup，标出书源数量
  → 每完成一个源就增量通知 UI

本地 TXT
  → FilePicker（仅 .txt）
  → TxtBookParser（UTF-8 / GBK、书名作者、章节标题）
  → LocalImportService
  → books / chapters（source_url = local://txt，正文已写入）
  → Reader（跳过书源与远程目录，直接读本地章节）
```

正文统一在 `ChapterContentLoader` 进入分页前做一次规范化：
`htmlToPlainText`（把 `<br>`、`<p>`、`<div>` 等块级标签转成换行）→ `replaceRegex` 清洗 →
`normalizeChapterBody`（合并空行、每段加两个全角空格）。旧缓存也会在读取时被修正。

## 设计系统

- 页面固定白 / 黑底；12 套双色主题只切换强调色与辅助色。
- `ColorScheme.primary` 使用当前背景上可见的主题色，用于按钮、书脊等填充；强调色接近底色时自动换用辅助色，亮黄 / 荧光色不整页铺底。
- 文字与图标使用 `AppColors.accentOf`：保持色相，按背景亮度调整明度到 WCAG AA 4.5:1；辅助色接近底色时用 `AppColors.companionOf` 做小面积点缀。主题色块展示原始双色，不再与界面显示对不上。
- 默认主题「鸢尾蓝 · 流光白」；主题定义在 `design/theme/theme_presets.dart`。
- 每页只保留一行 `PageHeader`，不保留品牌顶栏、英文副题和档案编号；底部为白底四页签 Dock，不使用胶囊。
- 发现页使用平面列表；书架页与本地页共用 `design/components/bookshelf_3d.dart` 的 3D 模式。全新安装默认 3D，旧版 `coverGrid` 偏好保留为网格 / 列表。
- 每页标题、底栏选中项、书架筛选使用主题强调色；底栏与筛选的下划线使用辅助色。
- 不使用重模糊；header / dock 都是实色白。
- 布局/主题测试在 `test/design/chrome_layout_test.dart`、`bookshelf_layout_test.dart`、`bookshelf_3d_dynamic_test.dart` 与 `theme_preset_test.dart`，覆盖 360 / 411 / 800 宽、明暗两套、1.3 倍文字缩放、数量增减与主题可读性。

## 数据库

- 单文件 `reader.db`，表：`books`、`chapters`、`sources`、`bookmarks`、`reading_history`、`tags`、`book_tags`、`replace_rules`。
- schema 版本为 8（v4 给 `chapters` 增 `volume_title` / `volume_ord`；v5 给 `books` 增 `on_shelf`、给 `chapters` 增 `info`；v6 增 `tags` / `book_tags`；v7 增 `replace_rules`；v8 给 `books` 增 `anchor_offset`）；`onUpgrade` 只增量建表 / 补列，`bookmarks` / `reading_history` 通过 `book_id` 外键级联删除，不清空用户数据。
- **`reader.db` 是唯一用户数据源**；阅读内核自带的 Room 库只作运行期 Cookie / 临时缓存，不进入备份，缓存页可单独统计与清理。
- 本地 TXT 复用现有 `books` / `chapters`，不新增表；`source_url` 以 `local://` 开头，章节正文直接存入 `chapters.body`。
- 备份与恢复：`features/backup/` 导出 `books` / `bookmarks` / `reading_history` / `tags` / `book_tags` / `replace_rules`（可选 `sources` 与白名单设置）为 gzip JSON，不含 `chapters` 正文与分页缓存；导入为单事务合并。
- 任何后续 schema 改动仍必须先补增量迁移与迁移测试。

## 验证

- `flutter analyze`：通过。
- `flutter test --concurrency=1`：全部通过；联网类用例（TLS 实站、阅友小说、源码包校验）需对应环境变量开启，默认跳过。
- 书源仓储事务测试使用 `sqflite_common_ffi` 的真实内存数据库，覆盖默认保留、明确覆盖与跨分块失败回滚；迁移测试覆盖旧库升级与目录重排；备份测试覆盖导出/预览/恢复空库/合并语义/非法文件拒绝。
- release arm64 APK：R8 + `shrinkResources`，使用项目自有 keystore 签名。
