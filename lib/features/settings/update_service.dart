import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Release info for a newer version.
///
/// The app only ever checks and opens the release page (product decision 9):
/// no in-app download, no installer, no extra permissions.
class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.notes,
    required this.pageUrl,
  });

  final String tag;

  /// Tag without the leading `v` (e.g. `2.1.0+8`).
  final String version;
  final String notes;
  final String pageUrl;
}

/// GitHub Releases check for [repository].
class UpdateService {
  UpdateService({Dio? dio, String? apiBase})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {'User-Agent': 'langhuan-reader'},
            ),
          ),
      _apiBase = apiBase ?? 'https://api.github.com';

  static const String repository = 'LJX-110/langhuan-reader';
  static const Duration autoCheckInterval = Duration(hours: 24);

  final Dio _dio;
  final String _apiBase;

  String get latestReleaseUrl =>
      '$_apiBase/repos/$repository/releases/latest';

  /// Local `version+build` from package_info; falls back to the cached prefs
  /// value that bootstrap writes on every launch.
  Future<String> localVersion() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      return '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      return SpUtil.getString(PrefsKeys.version, defValue: '');
    }
  }

  /// True when the 24h auto-check window has passed.
  bool get autoCheckDue {
    final last = SpUtil.getInt(PrefsKeys.updateLastCheck, defValue: 0);
    if (last <= 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    return age >= autoCheckInterval.inMilliseconds;
  }

  /// Latest release newer than the installed build, or null when up to date.
  ///
  /// [force] bypasses the 24h window (manual checks). Network / API failures
  /// throw; the silent startup caller swallows them.
  Future<UpdateInfo?> check({bool force = false}) async {
    if (!force && !autoCheckDue) return null;
    final local = await localVersion();
    final resp = await _dio.get<Map<String, dynamic>>(
      latestReleaseUrl,
      options: Options(headers: const {'Accept': 'application/vnd.github+json'}),
    );
    final data = resp.data;
    if (data == null) return null;
    final tag = (data['tag_name'] ?? '').toString().trim();
    final pageUrl = (data['html_url'] ?? '').toString().trim();
    if (tag.isEmpty || pageUrl.isEmpty) return null;
    // A successful check starts the 24h window even when up to date.
    SpUtil.putInt(
      PrefsKeys.updateLastCheck,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!isRemoteNewer(local: local, remoteTag: tag)) return null;
    return UpdateInfo(
      tag: tag,
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (data['body'] ?? '').toString(),
      pageUrl: pageUrl,
    );
  }
}

/// Parse `v2.1.0+8` / `2.0.0` into `[major, minor, patch, build]`.
@visibleForTesting
List<int>? parseVersionTuple(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final parts = s.split('+');
  final core = parts[0].split('.');
  final nums = <int>[];
  for (final part in core) {
    final n = int.tryParse(part);
    if (n == null) return null;
    nums.add(n);
  }
  while (nums.length < 3) {
    nums.add(0);
  }
  final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return [nums[0], nums[1], nums[2], build];
}

/// True when [remoteTag] is a strictly newer version than [local].
///
/// Unparseable formats are ignored (never report an update we cannot order).
@visibleForTesting
bool isRemoteNewer({required String local, required String remoteTag}) {
  final l = parseVersionTuple(local);
  final r = parseVersionTuple(remoteTag);
  if (l == null || r == null) return false;
  for (var i = 0; i < 4; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}
