import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:langhuan/core/utils/app_log.dart';
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
    // Many novel sites ship an incomplete TLS chain that Dart's bundled root
    // store rejects. Retry only after a handshake failure, never pre-emptively.
    _lenientDio = Dio(options())
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, _, _) => true;
          return client;
        },
      );
  }

  static final SourceHttp instance = SourceHttp._();
  late final Dio _dio;
  late final Dio _lenientDio;

  /// Big5 has no Dart codec; Android decodes it via java.nio.charset.
  static const MethodChannel _charsetChannel = MethodChannel(
    'langhuan/charset',
  );

  /// Session cookies per host. Legado sources often need the search page's
  /// cookie when fetching detail / toc / content.
  final Map<String, Map<String, String>> _cookieJar = {};

  Future<Response<List<int>>> _send(
    String url,
    Options options,
    Object? data,
  ) async {
    final host = Uri.tryParse(url)?.host ?? '';
    final headers = Map<String, String>.from(options.headers ?? const {});
    final hasCookie = headers.keys.any((key) => key.toLowerCase() == 'cookie');
    if (!hasCookie && host.isNotEmpty) {
      final jar = _cookieJar[host];
      if (jar != null && jar.isNotEmpty) {
        headers['cookie'] = jar.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; ');
      }
    }
    options.headers = headers;

    try {
      final response = await _dio.request<List<int>>(
        url,
        data: data,
        options: options,
      );
      _saveCookies(host, response.headers);
      return response;
    } on DioException catch (e) {
      if (!_isTlsError(e)) rethrow;
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
    if (host.isEmpty) return;
    final rawList = headers['set-cookie'];
    if (rawList == null || rawList.isEmpty) return;
    final jar = _cookieJar.putIfAbsent(host, () => <String, String>{});
    for (final raw in rawList) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      final lower = raw.toLowerCase();
      final expired =
          lower.contains('max-age=0') ||
          lower.contains('expires=thu, 01 jan 1970');
      if (expired || value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
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
    final options = Options(
      method: req.method,
      headers: req.headers,
      contentType: req.method == 'POST'
          ? Headers.formUrlEncodedContentType
          : null,
    );
    final response = await _send(url, options, req.body);
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
