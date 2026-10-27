# 项目工作指引

本文件只记录本项目特有的约定；通用协作、备份、安全边界、验证规则沿用全局 `AGENTS.md`。

## 产品定位

- 个人自用的 Android 网络小说阅读器，目标设备为 Redmi K90 至尊版，只出 arm64 APK。
- 东方古风、书阁气质；不做通用阅读平台，不做社区、账号、听书。本地只支持 TXT 导入，不接 EPUB / MOBI / PDF。
- 应用不内置任何书源，也不提供任何公开书源列表或默认仓库地址。
- 只保留「私有书源仓库」接口：由使用者填写自己的 JSON 地址，手动同步。
- 书源导入与仓库同步默认保留本地规则；只有用户明确确认后才覆盖，写库失败不得留下半批数据。

## 身份

- 应用名：**琅嬛阁**；当前版本 `2.1.1`。
- Android 包名：`com.langhuan.reader`；Dart 包名：`langhuan`。
- 上游底本：Apache-2.0；固定信息见 `docs/UPSTREAM.md`。
- 必须保留 `LICENSE`、`NOTICE` 和第三方许可文本；界面不保留上游名称、链接、邮箱、截图。许可归属只放在 `NOTICE` 与 `docs/UPSTREAM.md`，其他文档不重复上游链接。
- Wenku8-Local（`参考\Wenku8-Local-main`）可直接移植代码用于本项目（2026-10-26 用户决定放弃「只作视觉参考」约束）；其原始许可为 GPL-3.0，仓库对外发布时的许可标注待确认前不动 `LICENSE`。

## 技术边界

- Flutter stable 3.44.x / Dart 3.12.x，Android SDK 36，Java 17。
- 不引入 Firebase、崩溃上报、OTA 自更新、账号体系。
- 书源引擎保持 Legado 子集；仓库 JSON 支持裸数组、`{data:[...]}`、`{sources:[...]}`。
- 数据库 schema 改动必须先做增量迁移，禁止沿用上游「升级即清库」的做法。
- 优先复用现有目录与命名；大规模移动文件前先写方案并确认。

## 构建

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

发布签名只使用本项目自己的 keystore；`key.properties`、`*.jks`、`google-services.json` 不入库。GitHub Actions 通过仓库 Secrets 获取同一份 keystore，配置见 `docs/SIGNING.md`。

## 提交

- 提交者固定为 `LJX-110 <LJX-110@users.noreply.github.com>`。
- 提交前清除 `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL`，或用同名环境变量覆盖；提交记录里不得出现 `trae-solo-agent` / `solo-agent@trae.ai`。

## 设计

- 4 个主页签：书架 / 发现 / 本地 / 我。
- 视觉方向：白 / 黑底 + 12 套双色主题；每页只留一行页面标题，不保留品牌顶栏、英文副题和档案编号；发现页是平面列表，3D 模式只用于书架页与本地页。
- 主题只改强调色与辅助色，页面正文仍用白 / 黑底；荧光色不整页铺底，保证正文可读。
- 主题色分两种用法：`ColorScheme.primary` 使用当前背景上可见的主题色，强调色接近底色时自动换用辅助色；文字 / 图标一律用 `AppColors.accentOf` 的同色相校正色，不得直接把原始亮色当文字色。
- 辅助色用于底栏下划线、筛选下划线、书脊边线等小面积点缀；接近底色的辅助色用 `AppColors.companionOf` 校正后再使用。
- 阅读器优先保证分页、进度恢复、目录与换源稳定；视觉改造不得碰坏 `PageContentReader` 的核心分页逻辑。
- 不使用重模糊或玻璃效果；header / dock 都是实色。

## 版本

`pubspec.yaml` 是唯一版本来源，递增、tag 与发布规则见 `docs/VERSIONING.md`。
上一发布版 `1.0.0`；当前版本线 `2.1.1`（待真机验证后发布），精确 build 号看 `pubspec.yaml` 与 GitHub Releases。范围与退出标准见 `docs/ROADMAP.md`。
