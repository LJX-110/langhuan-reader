# 琅嬛阁

> 一阁藏书，只读自己带来的书

个人自用的 Android 网络小说阅读器，Flutter 编写。数据全部保存在本机；应用不内置任何书源，也不提供公开书源列表或默认仓库地址。

当前版本线 `2.3.1`；发布与 APK 见 [Releases](https://github.com/LJX-110/langhuan-reader/releases/latest)。

## 功能

- **四个主页签**：书架 / 发现 / 本地 / 我，单行页面标题 + 实色底栏
- **书架**：连续 3D 立体书架（有限滚动、默认聚焦最近阅读），整理页拖动排序与批量删除；全部 / 在读 / 未读筛选
- **发现 / 搜索**：书源 `exploreUrl` 驱动的平面列表；搜索按「书名 + 作者」合并多源结果，支持关键词缓存、失败诊断与单源重试
- **详情 / 换源**：先展示页面再加载；换源并发扫描、增量显示、可停止
- **阅读器**：仿真 / 覆盖 / 无动画 / 纵向滚动四种翻页；纸张、字号、行距、段距、边距、对齐、字体实时调整；章内查找、书签、阅读记录与进度恢复；章节头显示字数与更新时间；专注模式与字重三档
- **目录 / 缓存**：分卷目录、目录搜索与章序直达；离线下载（排队、暂停继续、仅 WiFi）；按书清理缓存
- **本地 TXT**：UTF-8 / GBK 自动识别，按章节标题分章；多文件导入显示进度，解析在后台 isolate
- **书源**：CSS / XPath / JSON 规则，支持 POST、Cookie、Big5、替换捕获组、`@js:` 与 JS 选择器；导入校验、单源四步测试、批量体检、内置编辑器；私有仓库同步（失败不写半批）
- **12 套双色主题**：白 / 黑底不变，强调色与辅助色随主题切换

## 技术栈

Flutter 3.44.x / Dart 3.12.x ｜ Android SDK 36 ｜ Riverpod、sqflite、Dio ｜ Rust `book_pager` 原生分页（Dart 兜底）｜ 只构建 Android arm64

## 构建与发布

- 构建统一走 GitHub Actions：推 `v*` 标签自动构建并发布签名 APK（Secrets 配置见 [`docs/SIGNING.md`](docs/SIGNING.md)），main 推送产出构建 artifact。
- 本地仅用于排障：`flutter pub get` → `flutter analyze` → `flutter test`。

## 私有书源仓库

应用启动时没有书源。进入「我的 → 私有书源仓库」，填写自己维护的 JSON 地址（私有仓库可填只读 Token，仅存本机）并手动同步；格式与托管方式见 [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)。

## 数据与隐私

- 只申请 `INTERNET` 权限；无账号、无统计、无崩溃上报、无 OTA、无云同步。
- 阅读进度、书签、阅读记录与设置保存在本机 SQLite / SharedPreferences。
- 书源内容与使用行为由使用者自行负责。

## 文档

[路线](docs/ROADMAP.md) ｜ [架构](docs/ARCHITECTURE.md) ｜ [品牌](docs/BRAND.md) ｜ [书源仓库](docs/SOURCE_REPO.md) ｜ [签名](docs/SIGNING.md) ｜ [版本](docs/VERSIONING.md) ｜ [上游与许可](docs/UPSTREAM.md)

## 许可

本仓库按 **GPL-3.0** 分发（[`LICENSE`](LICENSE)）；上游底本为 Apache-2.0（[`third_party/Apache-2.0.txt`](third_party/Apache-2.0.txt)），其余第三方许可见 [`NOTICE`](NOTICE) 与 [`docs/UPSTREAM.md`](docs/UPSTREAM.md)。
