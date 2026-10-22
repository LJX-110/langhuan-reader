# 琅嬛阁

琅嬛阁是一个自用的 Android 网络小说阅读器，基于 Flutter。当前版本 `1.0.0+2`，Phase 0–4 已完成并通过真机验收，Phase 5 质量与发布进行中。

- 目标设备：Redmi K90 至尊版
- 产物：单个 arm64 APK
- 定位：个人阅读器，不做平台、不做社区、不做账号
- 书源：**不内置、不提供任何书源或公开书源列表**；只保留「私有书源仓库」接口，由使用者填写自己的 JSON 地址

## 当前能力

- 书架 / 发现 / 本地 / 我 四栏主页，单行页面标题 + 白底四页签 Dock
- 书架 2 / 3 列自适应大封面，显示作者、阅读进度，支持全部 / 在读 / 未读筛选
- 12 套双色主题：页面保持白 / 黑底，强调色用于填充、标题、底栏与筛选；文字使用同色相的可读色，亮色主题不再出现看不清的按钮
- 发现页立体书架：书脊、书页厚度、顶面、落地阴影、透视与吸附翻页
- 详情页编辑式布局：白底分区、缺失字段降级、加入书架 / 换源 / 继续阅读
- 搜索按「书名 + 作者」合并多源结果，标出书源数量；逐源返回，不再等整批
- 本地 TXT 导入：UTF-8 / GBK，自动分章，存入本机数据库
- 阅读器：仿真 / 覆盖 / 无动画 / 纵向滚动四种翻页，章内查找、纸张、字号、行距、段距、边距、对齐、字体、章节缓存、进度恢复
- 书签与阅读记录：当前页加书签、全部书签列表、最近阅读页续读
- 书源引擎（Legado 规则子集）：CSS / XPath / JSON、详情 / 目录 / 正文 POST、按 host 复用 Cookie、Big5 解码、`replaceRegex` 捕获组、正文清洗、书源测试与健康度
- 私有书源仓库：手动同步自己维护的 JSON；应用不联网自动更新，不保存默认地址
- 数据库 v3：`books` / `chapters` / `sources` / `bookmarks` / `reading_history`，升级只做增量建表，不清空已有数据
- 双页书图标与启动图

## 不做的范围

- iOS / Web / 桌面端、模拟器、多 ABI
- 应用商店发布、账号、社区、评论、云同步
- EPUB / MOBI / PDF 导入（本地只支持 TXT）、听书
- Firebase / 崩溃上报 / OTA 自更新
- 内置书源、默认书源仓库、公开书源下载地址

## 环境

- Flutter 3.44.x（Dart 3.12.x）
- Android SDK 36、Java 17
- Windows 开发，Android arm64 目标

```powershell
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
```

release 构建启用 R8 与 `shrinkResources`，并剔除其他 ABI。自有签名配置见 [`docs/SIGNING.md`](docs/SIGNING.md)。

## 私有书源仓库

应用启动时没有书源。进入「我的 → 私有书源仓库」，填写你自己的 JSON 地址并手动同步。格式与托管方式见 [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)。

仓库可以是裸书源数组，或：

```json
{
  "name": "我的书源",
  "version": "1",
  "updatedAt": "2026-10-21",
  "sources": []
}
```

应用不会自动联网更新，也不会保存任何默认地址。

## 目录

```text
lib/            Flutter 源码（app / core / data / design / features）
android/        Android 壳
native/         Rust 分页库源码
third_party/    本地补丁依赖
docs/           路线、架构、品牌、书源仓库、上游说明
备份/           本地备份，不入库
```

更多说明：

- [`docs/ROADMAP.md`](docs/ROADMAP.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/BRAND.md`](docs/BRAND.md)
- [`docs/SOURCE_REPO.md`](docs/SOURCE_REPO.md)
- [`docs/SIGNING.md`](docs/SIGNING.md)
- [`docs/UPSTREAM.md`](docs/UPSTREAM.md)

## 许可与归属

本项目基于上游 Apache-2.0 底本整理和重写。许可归属、保留的第三方许可与已移除内容见 [`NOTICE`](NOTICE) 和 [`docs/UPSTREAM.md`](docs/UPSTREAM.md)。

Wenku8 仅作为视觉参考，未复制其 GPL-3.0 代码。

## 状态

- [x] Phase 0 工具链、底本清理与实机启动
- [x] Phase 1 设计系统、12 套双色主题、四页签 Dock、搜索合并
- [x] Phase 1 真机 UI / 明暗 / 字号 / 滚动验收
- [x] Phase 2 发现 / 书架 / 详情 / 搜索 / 本地与真机验收
- [x] Phase 3 阅读器、章内查找与真机验收
- [x] Phase 4 数据库增量迁移、书签、阅读记录、Cookie、POST、Big5、捕获组、健康度与真机验收
- [x] 修复书源导入刷新、书源详情、发现页超时、阅读器返回、正文刷新卡死
- [x] 主题修订：原始色填充 + 同色相可读文字色，标题 / 底栏 / 筛选随主题变化
- [x] `flutter analyze` 通过
- [x] `flutter test` 79 项通过（含 15 项布局 / 主题测试）
- [x] debug arm64 APK 构建通过
- [x] release arm64 APK 构建通过（29.7MB，R8 + `shrinkResources`；debug 为 99.6MB）
- [ ] Phase 5：集成测试、golden 测试、低端机性能
- [ ] 自有 release keystore
- [ ] 最终真机验收（P1–P4 全项回归）

debug APK：`build/app/outputs/flutter-apk/app-debug.apk`
release APK：`build/app/outputs/flutter-apk/app-release.apk`
