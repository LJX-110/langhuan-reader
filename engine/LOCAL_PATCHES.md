# 本地补丁说明（相对上游 huajideshutiao/legado master@d31c0a2，2026-11-01）

| # | 文件 | 改动 | 原因 |
|---|------|------|------|
| 1 | `settings.gradle.kts` | 裁剪 include 列表：只保留 `foundation` / `data` / `modules:{js-api, quickjs, quickjs-test, quickjs-android-native, quickjs-processor, rjpath}`；移除 app / ui / core / desktop* / headless / benchmark / treeview / ohos 条件块与 `tomlVersionOf` 辅助 | 只消费引擎依赖闭包，其余模块与本项目无关 |
| 2 | `build-logic/settings.gradle.kts` | 移除私有阿里云镜像（`mykmp-cn-shanghai.devops.aliyuncs.com`，个人环境 401） | `kotlin-dsl 6.6.4` 等插件在 gradlePluginPortal 可达；私有镜像不可用 |
| 3 | `build.gradle.kts` | 移除 ohos 打包任务（stage/verifyOhosNativeLibraries）与 iOS 版本同步任务（syncIosVersion）；保留 Material Icons 排除 | 本项目只用 Android/JVM 目标，上述任务引用不存在的目录且增加配置开销 |
| 4 | `settings.gradle.kts` | 两个仓库块的队首插入阿里云镜像（public / google / gradle-plugin），官方仓库保留兜底 | maven central 直连慢、易超时 |
| 5 | `gradle.properties` | 追加 `org.gradle.java.installations.auto-download=false` 与 `paths=D:\Minecraft\Java\jdk-21` | 不走 foojay 在线下载（曾龟速 78KB/s 且写 C 盘）；改用本机 JDK 21 |
| 6 | `modules/quickjs/build.gradle` | `buildJvmNativeLib` 增加"预编译库优先"闸门：存在 `prebuilt/jvm/<platformId>/legado_quickjs.dll` 时直接复用并跳过 CMake | 本机无 MSVC/MinGW，无法本地编译 JVM 版 quickjs；用官方桌面便携包中的预编译 DLL |
| 7 | `data/…/androidx/preference/PreferenceShim.kt` + `data/build.gradle.kts` | shim 从 `jvmAndAndroidMain` 移到 `jvmMain`；`androidMain` 增加 `api("androidx.preference:preference:1.2.1")` | Android 变体不再打包 androidx.preference 的 shim 类，消除与 App 侧（shared_preferences_android 依赖的）真实库的重复类；JVM 目标继续用 shim |
| 8 | 根 `build.gradle.kts` + 各模块构建脚本 | 本地 Maven 发布：group `com.langhuan.engine` / version `0.2.0` / 仓库 `../android/engine-repo`；关闭 KMP 元数据 KSP 任务与 JVM 发布任务 | Flutter App 以坐标消费引擎，App/CI 构建无需现场编译引擎；元数据 KSP 在 data 上有已知失败且 App 用不到 |
| 9 | `data` / `facade` / `foundation` / `modules:quickjs` / `modules:rjpath` | `compileSdk` 37 → 36 | App 侧 AGP 9.0.1 上限为 36；引擎 AAR 的 minCompileSdk 必须 ≤36 才能被 App 消费 |

## 升级上游流程

1. 拉取上游对应目录（`foundation/`、`data/`、`modules/`、`build-logic/`、`gradle/`、`gradlew*`、`gradle.properties`、`LICENSE`）；
2. 重放上表 1–3 项；
3. 跑 `:\data:compileKotlinJvm` + `:data:assembleRelease` 验证。

## runner 依赖（宿主验证）

- `runner/native/legado_quickjs.dll`：从官方桌面便携包提取（不随仓库分发）：
  `https://github.com/huajideshutiao/legado/releases/download/3.26.110111/windows_x64_portable.zip`
  → 解压 `legado-portable-windows-x64/app/resources/legado_quickjs.dll` 到 `engine/runner/native/`。
- 跑法：`gradlew -g E:\WorkSpace\Novel\.gradle-home :runner:run`

## 环境备注

- **构建命令固定加 `-g E:\WorkSpace\Novel\.gradle-home`**（Gradle 用户目录放 E 盘，避免写 C 盘）：
  ```powershell
  .\gradlew.bat -g E:\WorkSpace\Novel\.gradle-home :data:compileKotlinJvm
  ```
- JDK：工具链固定为 `D:\Minecraft\Java\jdk-21`（见补丁 5）；Gradle daemon 可跑在系统 JDK 17。
- Gradle 9.6.0 官方源超时的绕过：腾讯镜像 `mirrors.cloud.tencent.com/gradle/` 的 zip 预填到
  `<gradle-home>\wrapper\dists\gradle-9.6.0-bin\<hash>\` 并补 `.ok` 标记（已就位）。
- 本目录必须保持 **ASCII 路径**（AGP 拒绝中文路径）。
