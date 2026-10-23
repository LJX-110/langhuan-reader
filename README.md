# 琅嬛阁

> 一阁藏书，只读自己带来的书

个人自用的 Android 网络小说阅读器，Flutter 编写。书架、阅读进度、书签与书源都保存在本机；应用不内置任何书源，也不提供公开书源列表或默认仓库地址。

**当前版本线 v1.0.0**；最新构建号与 APK 见 [Releases](https://github.com/LJX-110/langhuan-reader/releases/latest)。

## 功能

- **四个主页签**：书架 / 发现 / 本地 / 我，单行页面标题 + 实色底栏
- **书架**：2 / 3 列自适应封面，全部 / 在读 / 未读筛选，阅读记录入口
- **发现**：立体书架、分类、换源，书源 `exploreUrl` 驱动
- **搜索**：按「书名 + 作者」合并多源结果，逐源返回并标出书源数量
- **详情**：简介、目录、加入书架、换源、继续阅读
- **本地 TXT**：UTF-8 / GBK 自动识别，按章节标题分章
- **阅读器**：仿真 / 覆盖 / 无动画 / 纵向滚动四种翻页；纸张、字号、行距、段距、边距、对齐、字体实时调整；章内查找、书签、阅读记录、进度恢复
- **正文排版**：块级标签转段落，段首缩进两格；顶栏显示书名与当前章节
- **书源引擎**：Legado 规则子集，支持 CSS / XPath / JSON、POST、Cookie、Big5、`replaceRegex` 捕获组、正文清洗与书源健康度
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

应用启动时没有书源。进入「我的 → 私有书源仓库」，填写自己维护的 JSON 地址并手动同步。格式与托管方式见 [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)。

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

项目基于 Apache-2.0 底本整理和重写。许可归属与第三方许可见 [`NOTICE`](NOTICE)、[`LICENSE`](LICENSE) 和 [`docs/UPSTREAM.md`](docs/UPSTREAM.md)。
