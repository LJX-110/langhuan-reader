# 品牌与应用身份

已选定：**琅嬛阁**，Android 包名 `com.langhuan.reader`，Dart 包名 `langhuan`。

- 一句话：一阁藏书，只读自己带来的书。
- 应用名延续「知白台」「黑冰匣」的气质：三字、古典、有实物意象，不直白叫「小说阅读器」。
- 界面只保留「琅嬛阁」与自己的副题，不出现上游名称、链接、邮箱或截图。

## 品牌资产（Phase 1）

当前图标与启动图由 `tool/generate_brand_assets.py` 生成，方向 **墨玉书函**：

- 墨玉色书函作为主体，浅米色题签写「琅」
- 青墨色书签，朱红小印做点缀
- 1024 px 母版绘制后按密度降采样，保证各尺寸比例一致
- 输出 `assets/brand/icon_master.png`、`icon_foreground.png`、`launch_logo.png`
- 同步写入 Android 各密度 `mipmap-*/ic_launcher*.png`、自适应图标 XML、`drawable-nodpi/launch_logo.png`
- `AndroidManifest.xml` 使用 `android:roundIcon="@mipmap/ic_launcher_round"`

重新生成：

```powershell
python tool/generate_brand_assets.py
```

母版源文件在 `assets/brand/`，不要只改 Android 产物。

## 视觉系统

### 色板

| 角色 | 色值 | 用途 |
|------|------|------|
| 宣纸 | `#F3F1EA` | 页面底色 |
| 纸白 | `#FAF8F2` | 卡片、搜索框、浅色表面 |
| 纸深 | `#E6E1D5` | 分隔、压暗层 |
| 墨 | `#1F1E1B` | 主文字 |
| 墨次 | `#5E594F` | 次级文字 |
| 墨淡 | `#8A8479` | 说明、占位 |
| 青墨 | `#2F4A45` | 主强调色、选中态 |
| 青墨浅 | `#78958C` | 暗色模式强调色 |
| 朱印 | `#9A3B2E` | 印章、提示、错误 |
| 界线 | `#D4CFC3` | 发丝线与描边 |

暗色基座为 `#141512`，表面 `#1D1F1C`，分隔 `#34362F`，正文 `#EDE7DA`。

颜色定义集中在 `lib/design/tokens/app_colors.dart`；界面优先通过 `ThemeData` 取色。

### 字体与版式

- 标题使用系统宋体 `AppType.serif`，字距略放宽，保持书阁档案感。
- 正文使用系统无衬线或用户选定的阅读字体；阅读器正文由 `ReadSetting` 独立控制，不随界面主题换色。
- 页头采用档案编号式小标：`01 / 藏书`、`01 / 寻书`、`01 / 书阁`。
- 英文副题固定为 `LANGHUAN / READING ARCHIVE`。
- 朱印方块只做小面积点缀，不大面积铺色。

### 界面构件

- `ArchiveBrandBar`：印章 + 应用名 + 档案副题；右侧放页面动作。
- `ArchiveLabel` / `ArchiveTitle`：章节眉标与大标题。
- `PaperSearchEntry`：书架 / 发现页头的纸面搜索入口。
- `SealMark`：界面内的小印章「琅」。
- `LanhuanDock`：底部三页签（书架 / 发现 / 我），青墨色选中胶囊；搜索不占页签。
- 玻璃 / 模糊只允许出现在 header 与 dock；低端机默认关闭重模糊。

## 包名规则

- 个人侧载，不经过应用商店；包名仍建议一次定好，后续换名需要改 `applicationId`、`namespace`、`MainActivity` 包路径和签名配置。
- 包名只使用小写字母与数字，不使用下划线。
- 如果希望和 GitHub 身份绑定，可用 `com.<github用户名>.reader`；用户名含连字符时去掉连字符。

## 命名记录

| 候选 | 含义 | 建议包名 | 气质 |
|------|------|----------|------|
| **琅嬛阁**（已选用） | 传说中藏书之地「琅嬛福地」，最贴私人书库 | `com.langhuan.reader` | 藏书、秘境、安静 |
| 芸阁 | 芸香草可防书蠹，古代藏书阁意象 | `com.yunge.reader` | 清雅、简短 |
| 无字斋 | 应用不内置书源，书由使用者带来 | `com.wuzi.reader` | 克制、略带机锋 |
| 砚冰斋 | 砚台结冰仍可读书，与「黑冰匣」同一冷冽气质 | `com.yanbing.reader` | 冷、硬朗、文房 |
| 雪窗阁 | 囊萤映雪、雪窗夜读 | `com.xuechuang.reader` | 清冷、勤读 |
| 青简阁 | 青简指古代竹简、典籍 | `com.qingjian.reader` | 古朴、书卷 |

## 后续

- 图标方向已落地；如后续提供参考图，再统一调整印章、边框与启动页。
- 阅读器纸色、字体、翻页视觉保持独立，不因界面改版而重做。
- 不复制 Wenku8 等第三方的 GPL 视觉资产。
