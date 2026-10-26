import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/utils/redact.dart';

void main() {
  group('Redact.url', () {
    test('drops query values, userinfo and fragment', () {
      final redacted = Redact.url(
        'https://user:pass@example.com:8443/search?q=斗破&token=SECRET#frag',
      );
      expect(redacted, 'https://example.com:8443/search?…#…');
      expect(redacted, isNot(contains('SECRET')));
      expect(redacted, isNot(contains('user')));
      expect(redacted, isNot(contains('pass')));
      expect(redacted, isNot(contains('斗破')));
    });

    test('keeps a path without query', () {
      expect(
        Redact.url('http://127.0.0.1:8080/book/1'),
        'http://127.0.0.1:8080/book/1',
      );
    });

    test('returns empty for non-http or malformed input', () {
      expect(Redact.url(''), isEmpty);
      expect(Redact.url('ftp://example.com/a'), isEmpty);
      expect(Redact.url('not a url'), isEmpty);
    });
  });

  group('Redact.forLog', () {
    test('redacts http URLs that carry a query string', () {
      expect(
        Redact.forLog('https://ex.com/read?sign=SECRET&t=1'),
        'https://ex.com/read?…',
      );
      expect(Redact.forLog('https://ex.com/read?sign=SECRET'), isNot(contains('SECRET')));
    });

    test('keeps query-free URLs and short labels', () {
      expect(Redact.forLog('https://ex.com/read/1'), 'https://ex.com/read/1');
      expect(Redact.forLog('/b/229093.html'), '/b/229093.html');
      expect(Redact.forLog('阅友小说'), '阅友小说');
    });

    test('hides unparseable strings instead of leaking their query', () {
      expect(Redact.forLog('custom://x?token=SECRET'), '(url hidden)');
    });
  });
}
