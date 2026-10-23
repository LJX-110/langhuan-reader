import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/net/session_cookies.dart';

void main() {
  setUp(SessionCookies.clear);
  tearDown(SessionCookies.clear);

  test('builds a host-scoped cookie header', () {
    SessionCookies.saveFromSetCookie('example.com', [
      'sid=abc; Path=/; HttpOnly',
      'theme=dark',
      'broken',
      '=empty',
    ]);

    expect(
      SessionCookies.headerForUrl('https://example.com/a.jpg'),
      'sid=abc; theme=dark',
    );
    expect(
      SessionCookies.headerForUrl('https://cdn.example.com/a.jpg'),
      isNull,
    );
    expect(SessionCookies.headerForUrl('not a url'), isNull);
  });

  test('expired and empty cookies are removed', () {
    SessionCookies.saveFromSetCookie('example.com', ['sid=abc']);
    SessionCookies.saveFromSetCookie('example.com', [
      'sid=gone; Max-Age=0',
      'empty=',
    ]);

    expect(SessionCookies.headerForUrl('https://example.com/'), isNull);
  });
}
