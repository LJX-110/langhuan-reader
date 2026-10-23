[CmdletBinding()]
param(
    [ValidateSet('build', 'patch', 'minor', 'major')]
    [string]$Part = 'build',

    # Print the next version without touching pubspec.yaml.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repo 'pubspec.yaml'
$text = [IO.File]::ReadAllText($pubspecPath)
$match = [regex]::Match($text, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$')
if (-not $match.Success) {
    throw 'pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD'
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value
$currentVersion = "$major.$minor.$patch+$build"

# A release bump must start from a clean main, so the tag always identifies
# exactly the source that produced the APK.
$dirty = git -C $repo status --porcelain
if ($dirty) {
    throw 'Working tree is not clean. Commit or stash before bumping the version.'
}
$branch = git -C $repo rev-parse --abbrev-ref HEAD
if ($branch -ne 'main') {
    throw "Version bumps must run on main (current branch: $branch)."
}
$localHead = (git -C $repo rev-parse HEAD).Trim()
$remoteHead = ((git -C $repo ls-remote origin refs/heads/main) -split '\s+')[0]
if (-not $remoteHead -or $localHead -ne $remoteHead) {
    throw 'main is not synced with origin/main. Push or pull before bumping.'
}

# BUILD is the Android versionCode. It must stay above every local and remote
# tag, otherwise an older APK could win an upgrade.
$tagNames = @()
$tagNames += git -C $repo tag --list 'v*+*'
$remoteTags = git -C $repo ls-remote --tags origin
foreach ($line in $remoteTags) {
    if ($line -match 'refs/tags/(v\d+\.\d+\.\d+\+\d+)(\^\{\})?$') {
        $tagNames += $Matches[1]
    }
}
$tagBuilds = @()
foreach ($tag in $tagNames) {
    if ($tag -match '^v\d+\.\d+\.\d+\+(\d+)$') {
        $tagBuilds += [int]$Matches[1]
    }
}
$maxBuild = $build
if ($tagBuilds.Count -gt 0) {
    $maxBuild = [Math]::Max($maxBuild, ($tagBuilds | Measure-Object -Maximum).Maximum)
}
$nextBuild = $maxBuild + 1

switch ($Part) {
    'build' { }
    'patch' { $patch = $patch + 1 }
    'minor' { $minor = $minor + 1; $patch = 0 }
    'major' { $major = $major + 1; $minor = 0; $patch = 0 }
}

$nextVersion = "$major.$minor.$patch+$nextBuild"
$nextTag = "v$nextVersion"

if (git -C $repo tag --list $nextTag) {
    throw "Tag $nextTag already exists locally."
}
if (git -C $repo ls-remote --tags origin "refs/tags/$nextTag") {
    throw "Tag $nextTag already exists on origin."
}

if ($DryRun) {
    Write-Output "current: $currentVersion"
    Write-Output "next:    $nextVersion ($nextTag)"
    return
}

$updated = $text.Substring(0, $match.Index) +
    "version: $nextVersion" +
    $text.Substring($match.Index + $match.Length)
[IO.File]::WriteAllText($pubspecPath, $updated, [Text.UTF8Encoding]::new($false))

Write-Output "pubspec.yaml: $currentVersion -> $nextVersion"
Write-Output 'Next:'
Write-Output '  git add pubspec.yaml'
Write-Output "  git commit -m `"release: $nextTag`""
Write-Output "  git tag -a $nextTag -m `"琅嬛阁 $nextVersion`""
Write-Output "  git push origin main $nextTag"
