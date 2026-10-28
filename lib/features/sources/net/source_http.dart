import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:langhuan/core/net/session_cookies.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/perf_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fast_gbk/fast_gbk.dart';

/// Shared Dio client for book-source fetches (independent of official API).
class SourceHttp {
  SourceHttp._() {
    BaseOptions options() => BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.bytes,
      validateStatus: (c) => c != null && c < 500,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    );
    _dio = Dio(options());
    // Some novel sites ship an incomplete TLS chain. Lenient retry is opt-in
    // per source (`X-Langhuan-Insecure-TLS: 1` in the source header); sources
    // without it keep strict certificate validation.
    _lenientDio = Dio(options())
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, _, _) => true;
          return client;
        },
      );
  }

  /// Header a private source can set to request a one-time lenient TLS retry.
  static const String insecureTlsHeader = 'x-langhuan-insecure-tls';

  /// True when [headers] request the lenient retry **and** the user has turned
  /// on the local high-risk switch.
  ///
  /// The header alone must never be enough: a repository JSON could otherwise
  /// silently authorize a MITM certificate. [localOptIn] is injectable for
  /// tests; production reads [PrefsKeys.allowInsecureTls] (default false).
  static bool allowsInsecureTls(
    Map<String, String> headers, {
    bool? localOptIn,
  }) {
    var optedIn = localOptIn;
    if (optedIn == null) {
      try {
        optedIn = SpUtil.getBool(PrefsKeys.allowInsecureTls, defValue: false);
      } catch (_) {
        // Unit tests / early calls before bootstrap: strict by default.
        optedIn = false;
      }
    }
    if (!optedIn) return false;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != insecureTlsHeader) continue;
      final value = entry.value.trim().toLowerCase();
      return value == '1' || value == 'true' || value == 'yes';
    }
    return false;
  }

  /// Remove the control header so it never reaches the remote site.
  static Map<String, String> stripInsecureTlsHeader(
    Map<String, String> headers,
  ) {
    headers.removeWhere((key, _) => key.toLowerCase() == insecureTlsHeader);
    return headers;
  }

  static final SourceHttp instance = SourceHttp._();
  late final Dio _dio;
  late final Dio _lenientDio;

  /// Big5 has no Dart codec; Android decodes it via java.nio.charset.
  static const MethodChannel _charsetChannel = MethodChannel(
    'langhuan/charset',
  );

  /// Legado URL options may declare a structured JSON body, e.g.
  /// `{"method":"POST","body":{"keywords":"…","page":1,"sign":"…"}}`.
  /// Dio would form-encode a Map; JSON sources need the raw JSON text and the
  /// matching content type.
  static Object? _encodeBody(Object? body, Options options) {
    if (body is! Map && body is! List) return body;
    final headers = Map<String, String>.from(options.headers ?? const {});
    final hasJsonType = headers.keys.any(
      (k) => k.toLowerCase() == 'content-type' &&
          (headers[k] ?? '').toLowerCase().contains('json'),
    );
    if (!hasJsonType) {
      final hasType = headers.keys.any(
        (k) => k.toLowerCase() == 'content-type',
      );
      if (!hasType) headers['content-type'] = 'application/json';
      options.headers = headers;
    }
    try {
      return jsonEncode(body);
    } catch (_) {
      return body.toString();
    }
  }

  /// Session cookies per host live in [SessionCookies] so cover loads can use
  /// the same login session as source requests.
  Future<Response<List<int>>> _send(
    String url,
    Options options,
    Object? data,
  ) async {
    final perf = PerfLog.start('Source.http');
    final headers = Map<String, String>.from(options.headers ?? const {});
    final allowInsecureTls = allowsInsecureTls(headers);
    stripInsecureTlsHeader(headers);
    final hasCookie = headers.keys.any((key) => key.toLowerCase() == 'cookie');
    if (!hasCookie) {
      final cookie = SessionCookies.headerForUrl(url);
      if (cookie != null && cookie.isNotEmpty) {
        headers['cookie'] = cookie;
      }
    }
    options.headers = headers;
    final host = Uri.tryParse(url)?.host ?? '';

    try {
      final response = await _dio.request<List<int>>(
        url,
        data: data,
        options: options,
      );
      _saveCookies(host, response.headers);
      perf.done('${Redact.forLog(url)} status=${response.statusCode}');
      return response;
    } on DioException catch (e) {
      if (!_isTlsError(e)) rethrow;
      if (!allowInsecureTls) {
        AppLog.w(
          'SourceNet',
          'TLS rejected; enable the high-risk local switch and add '
              '"$insecureTlsHeader: 1" to the source header only if this site '
              'is trusted: $url',
          error: e.error,
        );
        rethrow;
      }
      AppLog.w(
        'SourceNet',
        'TLS chain rejected, retrying lenient: $url',
        error: e.error,
      );
      final response = await _lenientDio.request<List<int>>(
        url,
        data: data,
        options: options,
      );
      _saveCookies(host, response.headers);
      return response;
    }
  }

  void _saveCookies(String host, Headers headers) {
    final rawList = headers['set-cookie'];
    if (rawList == null || rawList.isEmpty) return;
    SessionCookies.saveFromSetCookie(host, rawList);
  }

  bool _isTlsError(DioException e) {
    final err = e.error;
    if (err is HandshakeException) return true;
    final text = '${err ?? ''} ${e.message ?? ''}';
    return text.contains('CERTIFICATE_VERIFY_FAILED') ||
        text.contains('HandshakeException');
  }

  Future<SourceResponse> fetch(AnalyzeRequest req) async {
    final url = req.url.trim();
    if (url.isEmpty ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
      throw ArgumentError.value(
        req.url,
        'url',
        'book-source request needs an absolute http(s) URL '
            '(JS searchUrl may have failed to resolve)',
      );
    }
    final hasContentType = req.headers.keys.any(
      (key) => key.toLowerCase() == 'content-type',
    );
    final options = Options(
      method: req.method,
      headers: req.headers,
      // Form default only; never override a source's JSON/XML Content-Type.
      contentType: req.method == 'POST' && !hasContentType
          ? Headers.formUrlEncodedContentType
          : null,
    );
    final response = await _send(url, options, _encodeBody(req.body, options));
    final bytes = response.data ?? <int>[];
    final ctype =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    // Prefer explicit request charset, then header, then meta/html sniff, then utf-8.
    var charset = req.charset.toLowerCase();
    if (charset.isEmpty || charset == 'utf-8') {
      charset = _charsetFrom(ctype, '');
    }
    if (charset.isEmpty) {
      charset = _sniffCharset(bytes) ?? 'utf-8';
    }
    final body = await _decode(bytes, charset);
    return SourceResponse(
      url: response.realUri.toString(),
      body: body,
      contentType: ctype,
      statusCode: response.statusCode ?? 0,
    );
  }

  String _charsetFrom(String contentType, String fallback) {
    final m = RegExp(
      r'charset=([^\s;]+)',
      caseSensitive: false,
    ).firstMatch(contentType);
    if (m != null) return m.group(1)!.replaceAll('"', '').toLowerCase();
    return fallback.toLowerCase();
  }

  /// Peek at the first ~2KB as latin1 to find <meta charset=...>
  String? _sniffCharset(List<int> bytes) {
    if (bytes.isEmpty) return null;
    final head = latin1.decode(
      bytes.take(bytes.length > 2048 ? 2048 : bytes.length).toList(),
      allowInvalid: true,
    );
    final m1 = RegExp(
      r'charset\s*=\s*["'
      "'"
      r']?([a-zA-Z0-9_\-]+)',
      caseSensitive: false,
    ).firstMatch(head);
    if (m1 != null) return m1.group(1)!.toLowerCase();
    final m2 = RegExp(
      r'encoding\s*=\s*["'
      "'"
      r']?([a-zA-Z0-9_\-]+)',
      caseSensitive: false,
    ).firstMatch(head);
    if (m2 != null) return m2.group(1)!.toLowerCase();
    return null;
  }

  Future<String> _decode(List<int> bytes, String charset) async {
    final c = charset.toLowerCase().replaceAll('_', '-');
    if (c.contains('big5')) {
      try {
        final text = await _charsetChannel.invokeMethod<String>('decode', {
          'bytes': Uint8List.fromList(bytes),
          'charset': c.contains('hkscs') ? 'Big5-HKSCS' : 'Big5',
        });
        if (text != null && text.isNotEmpty) return text;
      } catch (_) {
        // Fall through to the legacy best-effort decode.
      }
    }
    return _decodeSync(bytes, c);
  }

  String _decodeSync(List<int> bytes, String c) {
    try {
      if (c.contains('gb2312') ||
          c.contains('gbk') ||
          c.contains('gb18030') ||
          c == 'gb2312' ||
          c == 'gbk') {
        try {
          return gbk.decode(bytes);
        } catch (_) {
          // fall through
        }
      }
      if (c.contains('latin') || c.contains('iso-8859-1') || c == 'ascii') {
        return latin1.decode(bytes, allowInvalid: true);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      // Last resort: try gbk then utf8
      try {
        return gbk.decode(bytes);
      } catch (_) {
        try {
          return utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          return latin1.decode(bytes, allowInvalid: true);
        }
      }
    }
  }
}
