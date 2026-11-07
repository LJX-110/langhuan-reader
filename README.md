# 琅嬛阁

> 一阁藏书，只读自己带来的书

个人自用的 Android 网络小说阅读器，Flutter 编写。应用不内置任何书源，也不提供公开书源列表或默认仓库地址；阅读数据只保存在本机。

当前版本线 `2.3.2`；发布与 APK 见 [Releases](https://github.com/LJX-110/langhuan-reader/releases/latest)。

## 功能

- **书架**：连续 3D 立体书架、整理页排序与批量删除、在读 / 未读与标签筛选、随机一本
- **发现 / 搜索**：书源驱动的发现列表；多源结果按书名 + 作者合并，可暂停、诊断与单源重试
- **阅读**：仿真 / 覆盖 / 无动画 / 纵向滚动四种翻页；纸张、字号、行距、边距、字体实时调整；章内查找、书签、进度恢复、离线下载
- **本地 TXT**：UTF-8 / GBK 自动识别、按章节分章、批量导入
- **书源**：统一走阅读内核（CSS / XPath / JSON、POST、Cookie、`@js:`），支持导入校验、四步测试、私有仓库同步
- **外观**：12 套双色主题；详见 [功能说明](docs/FEATURES.md)

## 数据与隐私

- 只申请 `INTERNET`；无账号、无统计、无崩溃上报、无 OTA、无云同步；系统备份已关闭（`allowBackup=false`）；启动时仅静默检查一次版本号（24 小时节流）
- 阅读进度、书签、阅读记录与设置保存在本机 SQLite / SharedPreferences；可在「我的 → 备份与恢复」手动导出，引擎缓存可在缓存页单独清理
- 书源由使用者自行维护，内容与使用行为由使用者负责

## 构建与发布

- 构建统一走 GitHub Actions：推 `v*` 标签自动构建并发布签名 APK（Secrets 配置见 [`docs/SIGNING.md`](docs/SIGNING.md)），main 推送产出构建 artifact
- CI 会重建阅读内核 AAR 与 Rust 分页库再打包，仓库里的产物只作本地兜底；本地排障用 `flutter pub get` → `flutter analyze` → `flutter test`

## 文档

[功能](docs/FEATURES.md) ｜ [路线](docs/ROADMAP.md) ｜ [架构](docs/ARCHITECTURE.md) ｜ [品牌](docs/BRAND.md) ｜ [书源仓库](docs/SOURCE_REPO.md) ｜ [签名](docs/SIGNING.md) ｜ [版本](docs/VERSIONING.md) ｜ [上游与许可](docs/UPSTREAM.md)

## 许可

本仓库按 **GPL-3.0** 分发（[`LICENSE`](LICENSE)）；上游底本为 Apache-2.0（[`third_party/Apache-2.0.txt`](third_party/Apache-2.0.txt)），其余第三方许可见 [`NOTICE`](NOTICE) 与 [`docs/UPSTREAM.md`](docs/UPSTREAM.md)。
