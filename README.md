# 琅嬛阁

仄室藏山，一阁纳卷。

琅嬛阁是一款基于 Kotlin Multiplatform + Compose Multiplatform 的书籍管理与浏览应用，Android 是唯一维护与发布的平台；桌面 / iOS / 鸿蒙的代码保留在同一仓库，但已明确放弃，不适配、不验收、不发布。

## 平台

| 平台 | 状态 |
| --- | --- |
| Android | 唯一平台，`com.langhuan.reader`，minSdk 24 / targetSdk 36 |
| 桌面（Windows / macOS / Linux） | 已放弃，代码保留不再维护 |
| iOS | 已放弃，代码保留不再维护 |
| 鸿蒙 | 已放弃，代码保留不再维护 |

## 外观

- **12 套双色主题**：每套只有主色与辅助色两个色相，页面主体恒为白底或近黑底，强调色只落在标题竖线、下划线、书脊与选中态。
- **可读性校正**：文字与图标按 4.5:1 对比度自动修正，浅色主题不会出现刺眼的高饱和大面积铺色。
- **四页签**：书架 / 发现 / 本地 / 我，居中悬浮胶囊底栏，选中项带辅助色下划线。
- **3D 书架**：书脊 + 景深 + 抽书波，横向拖动吸附到整数格位，中心那本抽出显示封面，下拉更新目录。
- **阅读排版**：阅读菜单底部只保留一套「排版」面板 —— 字号 / 字距 / 行距 / 段距滑条，字重 / 字体 / 缩进 / 简繁 / 版面入口，纸色、翻页方式与配色板；不再有独立的「界面设置」弹窗。
- **衬线标题体系**：页眉、分组标题、书名统一使用衬线，正文使用系统字体。

图片源支持有限：解析链可识别图片类书源，但正文插图展示尚未完善。

## 目录结构

```
app/             Android 外壳与业务入口
ui/              共享 Compose 界面（外观改造集中在这里）
data/            数据层
core/            核心工具
foundation/      基础能力
modules/         子模块（js-api / quickjs / treeview / rjpath 等）
desktop*、iosApp、ohosApp        其它平台入口
build-logic/     Gradle 约定插件
```

## 构建

环境：JDK 21、Android SDK 37、Gradle 9.6。

```bash
# 只验编译
./gradlew -g <Gradle 用户目录> :app:compileAppDebugKotlin

# 调试包
./gradlew -g <Gradle 用户目录> :app:assembleDebug
```

Windows 下把 `./gradlew` 换成 `.\gradlew.bat`。工程路径必须是纯 ASCII，否则构建脚本会直接报错。

构建需要至少一次 git 提交（`versionCode` 由提交数推导）。正式包（R8 + 资源压缩，仅 arm64-v8a）由 GitHub Actions 在推送 `v*` 标签时构建并发布 Release，不在本地出包；日常 CI 会同时编译调试包做校验。

## 版本

`versionCode = 10000 + git 提交数`（浅克隆会直接报错，需要完整历史）；`versionName` 默认取 `app/build.gradle.kts` 中的基线版本（当前 `2.1.0`），打 tag 时 CI 用 `-PappVersion` 注入去掉 `v` 前缀的 tag 版本，保证包内版本与 tag 一致。

## 许可

本项目遵循 GNU General Public License v3.0，全文见 [LICENSE](LICENSE)。
