import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/net/source_http.dart';

/// Opt-in network check against a deliberately self-signed host.
///
/// Run with:
///   $env:LANGHUAN_LIVE_TLS = '1'; flutter test test/source/source_http_tls_live_test.dart
///
/// It is skipped in the normal suite so ordinary test runs stay offline.
void main() {
  final enabled = Platform.environment['LANGHUAN_LIVE_TLS'] == '1';

  group('SourceHttp live TLS', () {
    test('strict validation fails and explicit opt-in succeeds', () async {
      final url = Uri.parse('https://self-signed.badssl.com/');

      await expectLater(
        SourceHttp.instance.fetch(AnalyzeRequest(url: url.toString())),
        throwsA(
          isA<DioException>().having(
            (error) => '${error.error} ${error.message}',
            'TLS error',
            contains('CERTIFICATE_VERIFY_FAILED'),
          ),
        ),
      );

      final response = await SourceHttp.instance.fetch(
        AnalyzeRequest(
          url: url.toString(),
          headers: {SourceHttp.insecureTlsHeader: '1'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, contains('self-signed'));
    });
  }, skip: enabled ? false : 'set LANGHUAN_LIVE_TLS=1 to run');
}
