# langhuan-engine（琅嬛阁 · 引擎裁剪集）

「阅读」（Legado）书源引擎的裁剪副本，供琅嬛阁（Flutter 外壳）作原生后端使用。

- **上游**：https://github.com/huajideshutiao/legado（KMP 重构版"阅读"，GPL-3.0）
  - 基线：`master@d31c0a2`（2026-11-01；tarball sha256 `29E98B2B9724405DC90AE5C1BED1523313E5B1B0C62D09B1FB4A4A7621816FD4`）
- **内容**：
  - `foundation/`：工具层（utils / exception / constant / format / lib）
  - `data/`：领域与引擎核心 —— `model/analyzeRule`（规则引擎）、`model/webBook`（搜索/详情/目录/正文管线）、`model/script`（JS 桥）、`help/http`（OkHttp 管线）、Room 数据库层等
  - `modules/js-api|quickjs|quickjs-android-native|quickjs-processor|quickjs-test|rjpath`
  - `build-logic/`：约定插件（`legado.kmp.library` 等）
- **构建**（独立 Gradle 构建，自带 wrapper 9.6.0）：
  - 宿主验证：`./gradlew :data:compileKotlinJvm`
  - 引擎 JVM 测试：`./gradlew :data:jvmTest`（quickjs 桌面 native 需 cmake 工具链）
  - Android 目标：`./gradlew :data:assembleRelease`
- **本地改动**：见 `LOCAL_PATCHES.md`（升级上游时按该清单重放）。
- **许可**：GPL-3.0（见 `LICENSE`）；署名已并入仓库根 `NOTICE`。
