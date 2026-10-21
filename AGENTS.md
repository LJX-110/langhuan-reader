# 项目工作指引

本文件只记录本项目特有的约定；通用协作、备份、安全边界、验证规则沿用全局 `AGENTS.md`。

## 产品定位

- 个人自用的 Android 网络小说阅读器，目标设备为 Redmi K90 至尊版，只出 arm64 APK。
- 东方古风、纸墨书阁气质；不做通用阅读平台，不做社区、账号、听书、本地 TXT/EPUB 导入。
- 应用不内置任何书源，也不提供任何公开书源列表或默认仓库地址。
- 只保留「私有书源仓库」接口：由使用者填写自己的 JSON 地址，手动同步。

## 身份

- 应用名：**琅嬛阁**。
- Android 包名：`com.langhuan.reader`；Dart 包名：`langhuan`。
- 上游底本：Apache-2.0；固定信息见 `docs/UPSTREAM.md`。
- 必须保留 `LICENSE`、`NOTICE` 和第三方许可文本；界面不保留上游名称、链接、邮箱、截图。许可归属只放在 `NOTICE` 与 `docs/UPSTREAM.md`，其他文档不重复上游链接。
- Wenku8 只作视觉参考，不复制其 GPL-3.0 代码。

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
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
```

发布签名只使用本项目自己的 keystore；`key.properties`、`*.jks`、`google-services.json` 不入库。

## 设计

- 3 个主页签：书架 / 发现 / 我。
- 视觉方向：宋画、宣纸、墨色、青灰、留白；避免后台 Dashboard 感、塑料渐变、游戏 UI。
- 阅读器优先保证分页、进度恢复、目录与换源稳定；视觉改造不得碰坏 `PageContentReader` 的核心分页逻辑。
- 低端机默认关闭重模糊；玻璃效果只允许出现在 header/dock。

## 阶段性验收

详见 `docs/ROADMAP.md`。当前阶段：Phase 0 基线。
