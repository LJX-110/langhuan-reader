import 'dart:ui' as ui;

import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/reader/settings/reader_font_bootstrap.dart';
import 'package:langhuan/core/platform/system_ui.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

class AppInit {
  static FlutterExceptionHandler? _prevFlutterError;
  static ui.ErrorCallback? _prevPlatformError;

  /// Swallow image-resource / cover-load noise from FlutterError + platform dumps.
  static void _installQuietImageErrorFilter() {
    _prevFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isImageNoise(details.exception, details.library, details.context)) {
        // Keep a one-line breadcrumb in debug only.
        assert(() {
          debugPrint(
            '[Cover] suppressed: ${details.exceptionAsString().split('\n').first}',
          );
          return true;
        }());
        return;
      }
      final prev = _prevFlutterError;
      if (prev != null) {
        prev(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    _prevPlatformError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (PicWidget.isBenignCoverError(error) ||
          error.toString().contains('Invalid image data')) {
        assert(() {
          debugPrint(
            '[Cover] platform suppressed: ${error.toString().split('\n').first}',
          );
          return true;
        }());
        return true; // handled
      }
      final prev = _prevPlatformError;
      if (prev != null) return prev(error, stack);
      return false;
    };
  }

  static bool _isImageNoise(
    Object exception,
    String? library,
    DiagnosticsNode? context,
  ) {
    final lib = library ?? '';
    final ctx = context?.toString() ?? '';
    if (lib.contains('image resource') ||
        ctx.contains('image resource') ||
        ctx.contains('resolving an image') ||
        ctx.contains('while resolving an image')) {
      return true;
    }
    return PicWidget.isBenignCoverError(exception);
  }

  static Future init() async {
    WidgetsFlutterBinding.ensureInitialized();
    GestureBinding.instance.resamplingEnabled = true;
    // Cover CDN WebP/network failures are common; show placeholder, not red dump.
    _installQuietImageErrorFilter();

    await SpUtil.getInstance();
    // Extract bundled CJK TTF so Rust book_pager uses the same face as Flutter.
    await ReaderFontBootstrap.ensure();
    // Single-file reader.db — drop legacy multi-DB files (no migration).
    await ReaderDatabase.wipeLegacyDatabases();
    // Drop pre-reader.db SpUtil page-layout keys (`*pages*`).
    for (final key in SpUtil.getKeys().toList()) {
      if (key.contains('pages')) {
        SpUtil.remove(key);
      }
    }
    final router = FluroRouter();
    Routes.configureRoutes(router);
    Routes.router = router;
    await DirectoryUtil.getInstance();
    // Version label for「我的」页 (synced dynamically via package_info_plus).
    try {
      final pkg = await PackageInfo.fromPlatform();
      SpUtil.putString(PrefsKeys.version, pkg.version);
    } catch (_) {
      if (!SpUtil.haveKey(PrefsKeys.version) ||
          SpUtil.getString(PrefsKeys.version).isEmpty) {
        SpUtil.putString(PrefsKeys.version, '1.0.0');
      }
    }
    // Default: visible system bars. Only the reader body goes immersive.
    await SystemUiHelper.showSystemBars();
  }
}
