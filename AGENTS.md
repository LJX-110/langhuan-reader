# AGENTS.md

本文件约束在本仓库工作的 AI 与协作者。改动前先读，遇到冲突以本文件为准。

## 项目

- 名称：琅嬛阁（应用内、文档、注释统一用这个名字）
- 包名：`com.langhuan.reader`
- 技术栈：Kotlin Multiplatform + Compose Multiplatform（M2），AGP 9.4.1 / Kotlin 2.3.20 / Gradle 9.6.0，compileSdk 37 / targetSdk 36 / minSdk 24
- 模块：`app`（Android 外壳 + 业务入口）、`ui`（共享 Compose 界面）、`data`、`core`、`foundation`、`modules/*`
- 品牌与文案：统一称「琅嬛阁」，不引用上游项目名，也不使用其它同类产品的名称、栏目名与字样

## 改动边界

- 外观与交互改造只允许落在：
  - `ui/src/sharedUiMain/kotlin/com/langhuan/reader/ui/**`（Compose 界面层）
  - `ui/src/commonMain/composeResources/values*`（文案与资源）
  - `app/src/main/res/**`（Android 资源、图标、应用名）
  - `app/build.gradle.kts`（包名、版本、签名）
- `data` / `core` / `foundation` / `modules` 是业务内核，除非任务明确要求，不要改动。只读查询可以复用（例如 `Book.flowLocal()`）。
- 不引入第二条实现路径：同一种能力只保留一处实现，不加开关、不做静默兜底。

## 设计约定

- 主题：`LanghuanTheme.kt` 里的 12 套双色主题，每套只有主色与辅助色；页面主体恒为白底（`#FFFFFF`）或近黑底（`#0E0E0E`），不要把强调色铺成整页背景。
- 对比度：文字与图标走 `langhuanReadable(minRatio = 4.5f)`；大面积填充走 `langhuanThemeAccent`，小面积点缀走 `langhuanCompanion`。
- 颜色取值：只能用 `AppTheme.colors`（`AppColors`）里的字段，不要在页面里写死色值。新增语义色时先给 `AppColors` 加带默认值的字段，再在 `readAppColors()` 里由主题解析。
- 字体：页眉、分组标题、书名使用 `LanghuanType` 的衬线样式，正文保持系统字体。正文与标题若需分字体，必须同时改度量与绘制两侧，否则会错行。
- 组件：页眉 `LanghuanPageHeader`、搜索入口 `LanghuanSearchEntry`、分组标题 `LanghuanSectionTitle`、3D 书架 `LanghuanShelf`、皮肤弹窗 `LanghuanSkinDialog`。新增外观组件统一用 `Langhuan*` 前缀，放在与业务就近的 `component/` 目录。
- 图标：只保留一套「阁顶为书」图标（黛蓝 `#22344A` / 米白 `#F3EBDD`，两色，不用黄铜），启动页与图标同源；不提供换图标入口，也不保留旧图标资源。
- 3D 书架几何常量集中在 `LanghuanShelfGeometry`，不要在绘制代码里另写一套数字。
- 避免卡片投影、重描边、装饰性渐变这类堆料；层级靠留白、字重与那条主题色细线区分。

## 构建与验证

```bash
# 只验编译
.\gradlew.bat -g E:\WorkSpace\Novel\.gradle-home "-Dorg.gradle.java.installations.paths=D:\Minecraft\Java\jdk-17,D:\Minecraft\Java\jdk-21" :app:compileAppDebugKotlin --console=plain

# 调试包 / 正式包
.\gradlew.bat -g E:\WorkSpace\Novel\.gradle-home "-Dorg.gradle.java.installations.paths=D:\Minecraft\Java\jdk-17,D:\Minecraft\Java\jdk-21" :app:assembleDebug --console=plain
.\gradlew.bat -g E:\WorkSpace\Novel\.gradle-home "-Dorg.gradle.java.installations.paths=D:\Minecraft\Java\jdk-17,D:\Minecraft\Java\jdk-21" :app:assembleAppRelease --console=plain
```

- 主构建用 JDK 21；`build-logic` 与 `modules/quickjs-processor` 的 toolchain 固定 17，所以必须用上面的 `-D` 同时登记两个 JDK。写进 `gradle.properties` 的 `org.gradle.java.installations.paths` 在 Gradle 9 下不生效，别再往里加。
- 工程路径必须是纯 ASCII；`versionCode` 由 `git rev-list HEAD --count` 推导，仓库至少要有一个提交。
- 验收标准：编译通过即可，不做真机验收、不做视觉验收；没跑过的检查要在汇报里写明「未验证」。
- Kotlin daemon 在部分机器上会因临时目录权限回退到进程内编译，日志里出现 `AccessDeniedException` 不是失败。

## 工作方式

- 改大文件或重写前先备份到 `备份/YYYY-MM-DD/`（同日同文件只留首次）；新建与生成物不备份。
- 不擅自 `git commit` / `git push` / 打标签；需要提交时先问。
- 不擅自批量删除；删除前列出路径等确认。构建产物（`*/build`、`.gradle`、`.kotlin`）属于可再生文件，可以直接清理。
- 文档、注释、界面文案同一处变更要同步，不留下旧名字与旧说法。
