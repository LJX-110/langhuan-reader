import 'package:dio/dio.dart';

/// Sends a browser-like User-Agent for book-source requests.
class RequestInterceptor extends Interceptor {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 11; KB2000) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/93.0.4515.131 Mobile Safari/537.36';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('user-agent', () => _userAgent);
    handler.next(options);
  }
}
