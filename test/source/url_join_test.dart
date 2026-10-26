import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/util/url_join.dart';

void main() {
  group('urlJoin', () {
    test('keeps a query string on an absolute path', () {
      expect(
        urlJoin('https://a.com/list/1', '/cover.php?id=1'),
        'https://a.com/cover.php?id=1',
      );
    });

    test('does not throw on square brackets in a relative path', () {
      expect(
        urlJoin('https://a.com/book/1', '/files/a[1].jpg'),
        anyOf(
          'https://a.com/files/a%5B1%5D.jpg',
          'https://a.com/files/a[1].jpg',
          '/files/a[1].jpg',
        ),
      );
    });

    test('resolves ordinary relative paths and protocol-relative urls', () {
      expect(
        urlJoin('https://a.com/book/1', '../cover.jpg'),
        'https://a.com/cover.jpg',
      );
      expect(
        urlJoin('https://a.com', '//cdn.a.com/x.jpg'),
        'https://cdn.a.com/x.jpg',
      );
    });

    test('falls back to the raw value for JS-looking input', () {
      expect(
        urlJoin('https://a.com', 'let base_url = source.getVariable();'),
        'let base_url = source.getVariable();',
      );
    });
  });
}
