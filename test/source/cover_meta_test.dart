import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';

/// Sources without a cover rule (笔迷读 etc.) still ship an `og:image`;
/// `fetchCover` falls back to it so shelf rows do not stay blank.
void main() {
  test('reads og:image regardless of attribute order', () {
    const a =
        '<html><head><meta property="og:image" '
        'content="https://img.example/a.jpg"></head></html>';
    const b =
        '<html><head><meta content="https://img.example/b.jpg" '
        'name="og:image"></head></html>';
    expect(BookSourceEngine.coverFromHtmlMeta(a), 'https://img.example/a.jpg');
    expect(BookSourceEngine.coverFromHtmlMeta(b), 'https://img.example/b.jpg');
  });

  test('supports twitter:image and relative urls pass through raw', () {
    const html =
        '<meta name="twitter:image" content="/cover/1.jpg">'
        '<meta property="og:title" content="书名">';
    expect(BookSourceEngine.coverFromHtmlMeta(html), '/cover/1.jpg');
  });

  test('returns empty when the page has no social card image', () {
    expect(
      BookSourceEngine.coverFromHtmlMeta('<meta name="description" content="x">'),
      '',
    );
    expect(BookSourceEngine.coverFromHtmlMeta(''), '');
  });
}
