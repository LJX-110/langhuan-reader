import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/repo/source_repo.dart';

/// Private GitHub repositories are fetched through the Contents API with a
/// bearer token; raw.githubusercontent is only used for public repos.
void main() {
  group('SourceRepo.resolveRequest', () {
    test('without a token the url is fetched as-is', () {
      final request = SourceRepo.resolveRequest(
        'https://raw.githubusercontent.com/O/R/main/packages/all.json',
        '',
      );

      expect(
        request.url,
        'https://raw.githubusercontent.com/O/R/main/packages/all.json',
      );
      expect(request.headers, isEmpty);
    });

    test('raw url with a token becomes the contents api', () {
      final request = SourceRepo.resolveRequest(
        'https://raw.githubusercontent.com/O/R/main/packages/all.json',
        'tok',
      );

      expect(
        request.url,
        'https://api.github.com/repos/O/R/contents/packages/all.json?ref=main',
      );
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(request.headers['Accept'], contains('github.raw'));
    });

    test('blob url with a token becomes the contents api', () {
      final request = SourceRepo.resolveRequest(
        'https://github.com/O/R/blob/main/sources/%E5%B0%8F%E8%AF%B4/a.json',
        'tok',
      );

      expect(
        request.url,
        'https://api.github.com/repos/O/R/contents/sources/%E5%B0%8F%E8%AF%B4/a.json?ref=main',
      );
    });

    test('an api url keeps its own query', () {
      final request = SourceRepo.resolveRequest(
        'https://api.github.com/repos/O/R/contents/packages/all.json?ref=dev',
        'tok',
      );

      expect(request.url, contains('ref=dev'));
      expect(request.headers['Authorization'], 'Bearer tok');
    });

    test('a token on a non-github host is rejected', () {
      expect(
        () => SourceRepo.resolveRequest('https://example.com/sources.json', 'tok'),
        throwsFormatException,
      );
    });

    test('malformed github urls are rejected', () {
      expect(
        () => SourceRepo.resolveRequest('https://github.com/O/R', 'tok'),
        throwsFormatException,
      );
      expect(
        () => SourceRepo.resolveRequest('https://github.com/O/R/tree/main', 'tok'),
        throwsFormatException,
      );
    });
  });

  test('fetch without a token still reads a public JSON repo', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final response = request.response..headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'name': '我的书源',
          'version': '3',
          'sources': [
            {
              'bookSourceUrl': 'https://ex.com',
              'bookSourceName': '示例源',
              'searchUrl': '/search?q={{key}}',
              'ruleSearch': {'bookList': '.item', 'name': 'a@text'},
            },
          ],
        }),
      );
      await response.close();
    });

    final fetched = await SourceRepo.fetch(
      'http://127.0.0.1:${server.port}/all.json',
    );

    expect(fetched.name, '我的书源');
    expect(fetched.version, '3');
    expect(fetched.count, 1);
  });
}
