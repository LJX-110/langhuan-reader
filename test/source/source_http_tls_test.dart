import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/net/source_http.dart';

void main() {
  group('SourceHttp TLS policy', () {
    test('lenient retry requires an explicit per-source opt-in', () {
      expect(SourceHttp.allowsInsecureTls({}), isFalse);
      expect(
        SourceHttp.allowsInsecureTls({'X-Langhuan-Insecure-TLS': '1'}),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({'x-langhuan-insecure-tls': 'true'}),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({'x-langhuan-insecure-tls': 'yes'}),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({'x-langhuan-insecure-tls': '0'}),
        isFalse,
      );
    });

    test('control header is stripped before the request is sent', () {
      final headers = {
        'X-Langhuan-Insecure-TLS': '1',
        'Referer': 'https://example.com/',
      };

      final stripped = SourceHttp.stripInsecureTlsHeader(headers);

      expect(
        stripped.keys.any(
          (key) => key.toLowerCase() == SourceHttp.insecureTlsHeader,
        ),
        isFalse,
      );
      expect(stripped['Referer'], 'https://example.com/');
    });
  });
}
