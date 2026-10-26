import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/net/source_http.dart';

void main() {
  group('SourceHttp TLS policy', () {
    test('a repository header alone never authorizes lenient TLS', () {
      expect(
        SourceHttp.allowsInsecureTls({
          'X-Langhuan-Insecure-TLS': '1',
        }, localOptIn: false),
        isFalse,
      );
    });

    test('local opt-in still requires the per-source header', () {
      expect(SourceHttp.allowsInsecureTls({}, localOptIn: true), isFalse);
      expect(
        SourceHttp.allowsInsecureTls({
          'X-Langhuan-Insecure-TLS': '1',
        }, localOptIn: true),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({
          'x-langhuan-insecure-tls': 'true',
        }, localOptIn: true),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({
          'x-langhuan-insecure-tls': 'yes',
        }, localOptIn: true),
        isTrue,
      );
      expect(
        SourceHttp.allowsInsecureTls({
          'x-langhuan-insecure-tls': '0',
        }, localOptIn: true),
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
