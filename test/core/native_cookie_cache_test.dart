import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/net/native_cookie_cache.dart';

void main() {
  setUp(NativeCookieCache.clear);
  tearDown(NativeCookieCache.clear);

  test('matches only the exact host', () {
    NativeCookieCache.put('https://example.com/a.jpg', 'sid=abc');
    expect(
      NativeCookieCache.headerForUrl('https://example.com/a.jpg'),
      'sid=abc',
    );
    expect(
      NativeCookieCache.headerForUrl('https://cdn.example.com/a.jpg'),
      isNull,
    );
  });

  test('empty cookie removes the host entry', () {
    NativeCookieCache.put('https://example.com/', 'sid=abc');
    NativeCookieCache.put('https://example.com/', '');
    expect(NativeCookieCache.headerForUrl('https://example.com/'), isNull);
  });

  test('invalid url is ignored', () {
    NativeCookieCache.put('not a url', 'sid=abc');
    expect(NativeCookieCache.headerForUrl('not a url'), isNull);
  });
}
