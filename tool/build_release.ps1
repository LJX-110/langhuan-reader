# 中文目录下的 release 构建。
# Flutter 的 AOT snapshotter 在 Windows 上读不了非 ASCII 路径，这里用 ASCII
# 盘符映射绕过；构建产物仍在仓库的 build/ 目录。
param(
    [string]$Drive = "R:"
)

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$mapped = (subst | Select-String -Pattern "^$([regex]::Escape($Drive))" ) -ne $null

if (-not $mapped) {
    subst $Drive $root
    if ($LASTEXITCODE -ne 0) {
        throw "无法把 $root 映射到 $Drive"
    }
}

try {
    Push-Location "$Drive\"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
    flutter build apk --release --target-platform android-arm64
} finally {
    Pop-Location
    if (-not $mapped) {
        subst $Drive /D
    }
}
