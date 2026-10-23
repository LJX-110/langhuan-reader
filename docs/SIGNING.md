# 发布签名

本项目只使用自己的 release keystore。`android/key.properties` 与 `*.jks` 已在 `.gitignore` 中，不要提交。

## 1. 生成 keystore

密码自己定，别名固定为 `langhuan`：

```powershell
keytool -genkeypair -v `
  -keystore android/app/langhuan-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias langhuan
```

## 2. 配置 `android/key.properties`

```properties
storePassword=你的_store_密码
keyPassword=你的_key_密码
keyAlias=langhuan
storeFile=langhuan-release.jks
```

`storeFile` 相对 `android/app/`；也可以写绝对路径。

## 3. 构建

```powershell
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

## 4. GitHub Actions 自动发布

仓库 Secrets 需要四项：

- `ANDROID_KEYSTORE_BASE64`：`android/app/langhuan-release.jks` 的 Base64
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

生成 Base64：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/langhuan-release.jks"))
```

推送 `v*` 标签后，`.github/workflows/release-apk.yml` 会构建并上传签名 APK。

## 注意

- 备份 `.jks` 和密码；丢失后无法用同一包名覆盖升级。
- 未配置 `key.properties` 时，当前 Gradle 会回退到 debug 签名，只适合本地测试，不要发布。
- 每次发布前确认 `versionCode` 已递增；`version` 省略 `+N` 时 Flutter 默认 `versionCode = 1`。
