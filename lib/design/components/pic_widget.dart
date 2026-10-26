import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:langhuan/core/net/session_cookies.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

class PicWidget extends StatelessWidget {
  final String url;
  final double height;
  final double width;
  final BoxFit fit;
  final bool roll;
  final double radius;

  /// Page URL that hosts the cover. Some CDNs reject a request whose referer
  /// is only the image host, so callers should pass the book detail page.
  final String referer;

  /// Shown over the placeholder when the cover cannot be loaded.
  final String title;

  /// Source base URL; protocol-relative / relative cover paths resolve here.
  final String baseUrl;

  const PicWidget(
    this.url, {
    super.key,
    this.height = 115,
    this.width = 97,
    this.fit = BoxFit.cover,
    this.roll = false,
    this.radius = 0,
    this.referer = '',
    this.title = '',
    this.baseUrl = '',
  });

  /// Designed typographic placeholder: paper panel, companion spine strip and
  /// the book name set vertically. Reads as a deliberate cover, unlike the
  /// grey `nocover.jpg` it replaces.
  Widget _placeholder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? AppColors.surfaceDark : AppColors.paperDeep;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final spine = AppColors.companionOf(context).withValues(alpha: .55);
    final ink = dark ? AppColors.textMutedDark : AppColors.inkSoft;
    final name = title.trim();
    final fontSize = (width * .18).clamp(9.0, 14.0);
    final maxChars = (height / (fontSize * 1.25)).floor().clamp(1, 5);
    final chars = name.isEmpty
        ? const ['暂', '无', '封', '面']
        : name.substring(0, name.length > maxChars ? maxChars : name.length)
              .split('');
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: line, width: .5),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: spine),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ch in chars)
                  Text(
                    ch,
                    style: TextStyle(
                      fontFamily: AppType.serif,
                      fontSize: fontSize,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Normalize cover URLs: trim, protocol-relative, resolve against [base],
  /// common placeholders → empty.
  static String normalizeUrl(String raw, {String base = ''}) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('//')) s = 'https:$s';
    // HTML-escaped ampersands
    s = s.replaceAll('&amp;', '&');
    final lower = s.toLowerCase();
    if (lower.contains('loading.jpg') ||
        lower.contains('loading.png') ||
        lower.contains('placeholder') ||
        lower.contains('default_cover') ||
        lower.endsWith('/nocover.jpg') ||
        lower.endsWith('/nopic.gif')) {
      return '';
    }
    if (!(s.startsWith('http://') || s.startsWith('https://'))) {
      // Relative path: resolve against the source page before giving up.
      final b = base.trim();
      if (b.isEmpty || s.startsWith('data:')) return '';
      final joined = Uri.tryParse(b)?.resolve(s).toString() ?? '';
      if (joined.startsWith('http://') || joined.startsWith('https://')) {
        return joined;
      }
      return '';
    }
    return s;
  }

  Map<String, String> _headersFor(String src) {
    final host = Uri.tryParse(src)?.host ?? '';
    // Many novel CDNs check UA / Accept; some want a same-site referer.
    final ref = referer.trim();
    final refererValue =
        (ref.startsWith('http://') || ref.startsWith('https://'))
        ? ref
        : (host.isEmpty ? 'https://www.google.com/' : 'https://$host/');
    // Header values must stay ASCII — percent-encode CJK paths.
    final safeReferer = Uri.tryParse(refererValue)?.toString() ?? refererValue;
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Referer': safeReferer,
    };
    final cookie = SessionCookies.headerForUrl(src);
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  /// True when [error] is a cover download/decode failure worth hiding from
  /// the red error overlay. Keep this narrow: swallowing every network error
  /// also hides real bugs from the log.
  static bool isBenignCoverError(Object? error) {
    if (error == null) return false;
    final s = error.toString();
    return s.contains('Failed to load') ||
        s.contains('Invalid image data') ||
        s.contains('ImageDecoder') ||
        s.contains('NetworkImageLoadException');
  }

  @override
  Widget build(BuildContext context) {
    final src = normalizeUrl(url, base: baseUrl);
    Widget child;
    if (src.isEmpty) {
      child = _placeholder(context);
    } else {
      final cacheW = (width * MediaQuery.devicePixelRatioOf(context)).round();
      child = ExtendedImage.network(
        src,
        width: width,
        height: height,
        fit: fit,
        cache: true,
        // Cover CDNs often return broken/unsupported WebP — don't spam console.
        printError: false,
        clearMemoryCacheWhenDispose: false,
        clearMemoryCacheIfFailed: true,
        retries: 1,
        timeRetry: const Duration(milliseconds: 500),
        // Without timeLimit a connected-but-silent CDN leaves the placeholder
        // spinning forever and keeps the socket open.
        timeLimit: const Duration(seconds: 12),
        // Cover URLs are md5(url)-keyed; an explicit max age gives stale or
        // corrupted cache entries a chance to be replaced.
        cacheMaxAge: const Duration(days: 7),
        headers: _headersFor(src),
        cacheWidth: cacheW > 0 ? cacheW : null,
        loadStateChanged: (state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return _placeholder(context);
            case LoadState.failed:
              // Quiet failure: keep placeholder; optional one-line debug only.
              assert(() {
                final err = state.lastException;
                if (err != null && kDebugMode) {
                  final first = err.toString().split('\n').first;
                  debugPrint('[Cover] fail $src → $first');
                }
                return true;
              }());
              return _placeholder(context);
            case LoadState.completed:
              return null; // use default decoded image
          }
        },
      );
    }

    if (radius > 0) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    }
    return SizedBox(width: width, height: height, child: child);
  }
}
