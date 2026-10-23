# 版本号与发布

`pubspec.yaml` 的 `version` 是唯一版本来源，其他文档、tag、APK 文件名都以它为准。

## 格式

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

以 `1.0.0+5` 为例：

| 部分 | 值 | 用途 |
| --- | --- | --- |
| `MAJOR.MINOR.PATCH` | `1.0.0` | 用户看到的 `versionName` |
| `BUILD` | `5` | Android 的 `versionCode`，只增不减 |
| Git tag | `v1.0.0+5` | 必须与 `version` 完全一致 |
| APK 文件名 | `langhuan-v1.0.0+5-arm64.apk` | 由 tag 自动生成 |

## 递增规则

| 改动类型 | 示例 | 规则 |
| --- | --- | --- |
| 只改文档、注释，不重新出 APK | 不变 | 不提交版本变更，不 tag |
| 修 bug、兼容性、图标或小体验 | `1.0.0+5` → `1.0.1+6` | PATCH +1，BUILD +1 |
| 新增功能、可见行为增加 | `1.0.1+6` → `1.1.0+7` | MINOR +1，PATCH 归零，BUILD +1 |
| 大版本、不兼容的数据或结构 | `1.1.0+7` → `2.0.0+8` | MAJOR +1，MINOR/PATCH 归零，BUILD +1 |
| 同一版本重打 APK | `1.0.0+5` → `1.0.0+6` | 版本名不变，BUILD 必须 +1 |

`BUILD` 永远不重置，也不复用。即使从 `1.x` 升到 `2.0`，`BUILD` 也继续加一；Android 只认这个数字判断覆盖升级。

## 每次发布

1. 确认在 `main`、工作区干净、已同步 `origin/main`。
2. 用脚本递增版本，或手工修改 `pubspec.yaml`：
   ```powershell
   .\tool\bump_version.ps1 -Part patch -DryRun
   .\tool\bump_version.ps1 -Part patch
   ```
3. 运行 `flutter analyze` 和 `flutter test`。
4. 构建并验签：
   ```powershell
   flutter build apk --release --target-platform android-arm64
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
5. 提交 `pubspec.yaml`，创建 annotated tag，推送 `main` 和 tag：
   ```powershell
   git tag -a v1.0.1+6 -m "琅嬛阁 1.0.1+6"
   git push origin main v1.0.1+6
   ```
6. 等 GitHub Actions 的 `Release APK` 成功，检查 Releases 里的 APK 和 SHA-256。

## 硬规则

- 不手工创建 GitHub Release；只推 tag，让 workflow 发布。
- tag 一旦推送，不移动、不删除、不覆盖；做错了就发下一个 `BUILD`。
- tag 必须是 annotated tag，名称必须是 `v` + `pubspec.yaml` 的完整版本。
- `.github/workflows/release-apk.yml` 会校验 tag 与 `pubspec.yaml`；不一致直接失败。
- README 等文档只写 `MAJOR.MINOR.PATCH` 版本线，不写 build 号；精确版本看 `pubspec.yaml`、tag 和 Releases。
- 发布前 `git status --porcelain` 必须为空；版本提交和 tag 必须指向同一个 commit。
