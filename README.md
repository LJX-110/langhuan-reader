# 琅嬛阁

琅嬛阁是一个自用的 Android 网络小说阅读器，基于 Flutter。Phase 0 与 Phase 1 已完成，进入 Phase 2 的发现 / 书架 / 详情打磨。

- 目标设备：Redmi K90 至尊版
- 产物：单个 arm64 APK
- 定位：个人阅读器，不做平台、不做社区、不做账号
- 书源：**不内置、不提供任何书源或公开书源列表**；只保留「私有书源仓库」接口，由使用者填写自己的 JSON 地址

## 当前能力

- 书架 / 发现 / 我的 三栏主页，档案式页头 + 三页签 Dock
- 纸墨设计系统：宣纸、墨色、青灰、朱印，明暗两套主题
- 本地书源引擎（Legado 规则子集）
- 搜索按「书名 + 作者」合并多源结果，标出书源数量
- 仿真 / 覆盖 / 无动画 / 纵向滚动四种阅读方式
- 纸张主题、自定义字体、章节缓存、阅读进度
- 私有书源仓库：手动同步自己维护的 JSON
- P1 图标与启动图（墨玉书函）

## 不做的范围

- iOS / Web / 桌面端、模拟器、多 ABI
- 应用商店发布、账号、社区、评论、云同步
- 本地 TXT / EPUB 导入、听书
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
```

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

- [x] Android / Flutter 工具链
- [x] 上游底本清理，移除 Firebase、OTA、公开书源仓库
- [x] 私有书源仓库接口
- [x] Phase 0 实机安装启动验证（Redmi K90 至尊版）
- [x] Phase 1 纸墨设计 tokens 与明暗主题
- [x] Phase 1 档案式页头 + 三页签 Dock
- [x] Phase 1 书架 / 发现 / 我的 主页重构
- [x] Phase 1 搜索按书合并、多源计数
- [x] Phase 1 图标与启动图
- [x] `flutter analyze` 通过
- [x] `flutter test` 通过（66 项，含 6 项布局测试）
- [x] debug arm64 APK 构建通过
- [ ] Phase 1 真机 UI / 性能验收（待补测）
- [ ] 自有 release keystore
- [ ] Phase 2 书架与详情打磨

debug APK：`build/app/outputs/flutter-apk/app-debug.apk`
