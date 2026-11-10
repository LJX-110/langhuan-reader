# 琅嬛阁

仄室藏山，一阁纳卷。

琅嬛阁是一款基于 Kotlin Multiplatform + Compose Multiplatform 的书籍管理与浏览应用，Android 为主平台，桌面 / iOS / 鸿蒙保留同一套共享界面。

## 平台

| 平台 | 状态 |
| --- | --- |
| Android | 主力平台，`com.langhuan.reader`，minSdk 24 / targetSdk 36 |
| 桌面（Windows / macOS / Linux） | 共享界面可用，未做专项打磨 |
| iOS | 基本可用（`iosApp`） |
| 鸿蒙 | 构建开关 `enableOhosTarget` 打开后可用 |

## 外观

- **12 套双色主题**：每套只有主色与辅助色两个色相，页面主体恒为白底或近黑底，强调色只落在标题竖线、下划线、书脊与选中态。
- **可读性校正**：文字与图标按 4.5:1 对比度自动修正，浅色主题不会出现刺眼的高饱和大面积铺色。
- **四页签**：书架 / 发现 / 本地 / 我，居中悬浮胶囊底栏，选中项带辅助色下划线。
- **3D 书架**：书脊 + 景深 + 抽书波，横向拖动吸附到整数格位，中心那本抽出显示封面，下拉更新目录。
- **衬线标题体系**：页眉、分组标题、书名统一使用衬线，正文使用系统字体。

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
# 调试包
./gradlew -g <Gradle 用户目录> :app:assembleDebug

# 正式包（R8 + 资源压缩，仅 arm64-v8a）
./gradlew -g <Gradle 用户目录> :app:assembleAppRelease
```

Windows 下把 `./gradlew` 换成 `.\gradlew.bat`。工程路径必须是纯 ASCII，否则构建脚本会直接报错。

构建需要至少一次 git 提交（`versionCode` 由提交数推导）。

## 版本

`versionName` 由 `-PappVersion` 注入，本地构建默认 `2.0.0`；`versionCode = 10000 + 提交数`。

## 许可

本项目遵循 GNU General Public License v3.0，全文见 [LICENSE](LICENSE)。
