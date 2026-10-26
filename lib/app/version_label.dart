/// Version text shown in「我的」and the notice page.
const String unknownVersion = '未知';

/// Synthetic value written by older builds when package info failed.
const String legacyFallbackVersion = '1.0.0';

/// Whether [version] is the old fake fallback rather than a real cache.
bool isLegacyFallbackVersion(String? version) =>
    version?.trim() == legacyFallbackVersion;

/// Use the package version when available, then a previously stored version,
/// and finally an explicit unknown label. Never invent a release number.
String resolveAppVersion({String? packageVersion, String? cachedVersion}) {
  final fromPackage = packageVersion?.trim() ?? '';
  if (fromPackage.isNotEmpty) return fromPackage;
  final cached = cachedVersion?.trim() ?? '';
  if (cached.isNotEmpty) return cached;
  return unknownVersion;
}

String versionDisplayLabel(String version) {
  final value = version.trim();
  if (value.isEmpty || value == unknownVersion) return '版本未知';
  return 'v$value';
}
