# 应用身份

已选定：**琅嬛阁**，Android 包名 `com.langhuan.reader`，Dart 包名 `langhuan`。

应用名延续「知白台」「黑冰匣」的气质：三字、古典、有实物意象，不直白叫「小说阅读器」。以下候选保留作记录。

| 候选 | 含义 | 建议包名 | 气质 |
|------|------|----------|------|
| **琅嬛阁**（推荐） | 传说中藏书之地「琅嬛福地」，最贴私人书库 | `com.langhuan.reader` | 藏书、秘境、安静 |
| **芸阁** | 芸香草可防书蠹，古代藏书阁意象 | `com.yunge.reader` | 清雅、简短 |
| **无字斋** | 应用不内置书源，书由使用者带来 | `com.wuzi.reader` | 克制、略带机锋 |
| **砚冰斋** | 砚台结冰仍可读书，与「黑冰匣」同一冷冽气质 | `com.yanbing.reader` | 冷、硬朗、文房 |
| **雪窗阁** | 囊萤映雪、雪窗夜读 | `com.xuechuang.reader` | 清冷、勤读 |
| **青简阁** | 青简指古代竹简、典籍 | `com.qingjian.reader` | 古朴、书卷 |

## 包名规则

- 个人侧载，不经过应用商店；包名仍建议一次定好，后续换名需要改 `applicationId`、`namespace`、`MainActivity` 包路径和签名配置。
- 包名只使用小写字母与数字，不使用下划线。
- 如果希望和 GitHub 身份绑定，可用 `com.<github用户名>.reader`；用户名含连字符时去掉连字符。

## 临时图标

当前使用 `tool/generate_brand_assets.py` 生成的占位图标：宣纸底、墨色「琅」字、朱红小印。源文件在 `assets/brand/`，已写入 Android mipmap 与启动页。

这是占位方案，不是最终视觉。等你给参考图后，再定字体、印章、边框与启动页。

## 待确认

选定名称后，需要同步修改：

1. `android/app/build.gradle.kts` 的 `namespace` / `applicationId`
2. `AndroidManifest.xml` 的 `package` 与 `android:label`
3. `MainActivity.kt` 的包声明与目录
4. `lib/main.dart` 的 `MaterialApp.title`
5. `README.md`、`NOTICE`、关于页、免责声明
6. 应用图标与启动图
