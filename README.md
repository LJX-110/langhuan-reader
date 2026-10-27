# 琅嬛阁

> 一阁藏书，只读自己带来的书

个人自用的 Android 网络小说阅读器，Flutter 编写。书架、阅读进度、书签与书源都保存在本机；应用不内置任何书源，也不提供公开书源列表或默认仓库地址。

上一发布版 `v1.0.0`；当前版本线 `v2.1.1`（QA 包已构建，待真机验证后发布）。已发布版本与 APK 见 [Releases](https://github.com/LJX-110/langhuan-reader/releases/latest)。

## 功能

- **四个主页签**：书架 / 发现 / 本地 / 我，单行页面标题 + 实色底栏
- **书架**：连续 3D 立体书架（有限滚动、默认聚焦最近阅读），整理页可拖动排序与批量删除；全部 / 在读 / 未读筛选，阅读记录入口
- **发现**：平面列表、分类分页与空态重试入口，书源 `exploreUrl` 驱动
- **搜索**：按「书名 + 作者」合并多源结果，逐源返回；结果按书名相关度排序、支持关键词缓存与「全部 / 分组」范围；失败可看诊断、可单源重试
- **详情**：简介、目录、加入书架、换源、继续阅读
- **本地 TXT**：UTF-8 / GBK 自动识别，按章节标题分章；多文件导入显示 `x/N` 进度，解析在后台 isolate；3D 书架视图，删除带行内二次确认
- **阅读器**：仿真 / 覆盖 / 无动画 / 纵向滚动四种翻页；纸张、字号、行距、段距、边距、对齐、字体实时调整；章内查找、书签、阅读记录、进度恢复；章节头显示本章字数与更新时间，目录同步显示章节信息小字
- **正文排版**：块级标签转段落，段首缩进两格；顶栏显示书名与当前章节
- **分卷目录**：按书源 `isVolume` 规则识别分卷，目录显示分组卷头，阅读进度不受影响
- **章内预取**：向前 / 向后预取范围可在阅读设置里调整（默认前 1 后 2 章）
- **检查更新**：启动时静默检查 GitHub Releases（24h 节流），「我的」页可手动检查并打开发布页；不做应用内下载安装
- **书源引擎**：Legado 规则子集，支持 CSS / XPath / JSON、POST、Cookie、Big5、`replaceRegex` 捕获组、`@onclick` 与尾接 `@js:`、正文清洗与书源健康度
- **书源管理**：导入前结构校验（可只导入通过项）、单源四步测试（搜索 → 详情 → 目录 → 正文按需）、分组筛选与批量启停 / 移动分组 / 导出；失败时标明阶段与规则字段
- **书源同步**：手动 JSON / URL 导入与私有仓库同步都默认保留本地规则；只有用户确认后才覆盖，两种写入路径均整批事务，失败不留下半批数据；支持 GitHub 私有仓库（只读 Token，仅存本机）
- **网络安全**：HTTPS 默认严格校验；自签 / 缺链证书兼容需本地高风险开关与书源标记同时满足
- **12 套双色主题**：白 / 黑底不变，强调色与辅助色随主题切换；文字使用同色相可读色

## 技术栈

- Flutter 3.44.x / Dart 3.12.x，Android SDK 36，Java 17
- Riverpod、sqflite、Dio、fluro、extended_image
- Rust `book_pager` 原生分页，Dart 分页兜底
- 只构建 Android arm64

## 目录

```text
lib/            Flutter 源码（app / core / data / design / features）
android/        Android 壳、签名配置、MainActivity
native/         Rust 分页库
third_party/    本地补丁依赖（flutter_js）
test/           单元与布局测试
assets/         字体与品牌源文件
images/         阅读器占位封面
docs/           架构、路线、品牌、书源仓库、签名、上游说明
tool/           品牌图生成脚本
.github/        GitHub Actions
```

## 构建

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

发布签名使用本机 `android/key.properties` 与 `android/app/*.jks`，两者都不入库。没有配置 keystore 时会回退到 debug 签名，只适合本地测试。

推送 `v*` 标签时，GitHub Actions 会使用仓库 Secrets 里的 keystore 构建并上传签名 APK；配置步骤见 [`docs/SIGNING.md`](docs/SIGNING.md)。

## 私有书源仓库

应用启动时没有书源。进入「我的 → 私有书源仓库」，填写自己维护的 JSON 地址（GitHub 私有仓库可填只读 Token，只存本机）并手动同步。格式与托管方式见 [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)。

应用不会自动联网更新，也不会保存任何默认地址。

## 数据与隐私

- 只申请 `INTERNET` 权限，用于访问你自己的书源。
- 无账号、无统计、无崩溃上报、无 OTA、无云同步。
- 阅读进度、书签、阅读记录与设置保存在本机 SQLite / SharedPreferences。
- 书源内容与使用行为由使用者自行负责。

## 文档

- [`docs/ROADMAP.md`](docs/ROADMAP.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/BRAND.md`](docs/BRAND.md)
- [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)
- [`docs/SIGNING.md`](docs/SIGNING.md)
- [`docs/VERSIONING.md`](docs/VERSIONING.md)
- [`docs/UPSTREAM.md`](docs/UPSTREAM.md)

## 许可

本仓库按 **GPL-3.0** 分发（`LICENSE`）：上游底本为 Apache-2.0，3D 书架移植自 GPL-3.0 的 Wenku8-Local。许可归属、上游与第三方许可见 [`NOTICE`](NOTICE)、[`third_party/Apache-2.0.txt`](third_party/Apache-2.0.txt) 和 [`docs/UPSTREAM.md`](docs/UPSTREAM.md)。
