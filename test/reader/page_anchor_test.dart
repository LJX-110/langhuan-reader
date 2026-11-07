import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/entities/text_line.dart';
import 'package:langhuan/data/entities/text_page.dart';
import 'package:langhuan/features/reader/model/reading_session_lifecycle.dart';

ReadPage _page(List<int> charStarts) => ReadPage('正文' * 200, '第一章', 0, [
  for (var i = 0; i < charStarts.length; i++)
    TextPage(
      [TextLine.simple('第 $i 页')],
      24,
      pageIndex: i,
      charStart: charStarts[i],
      charEnd: charStarts[i] + 60,
    ),
]);

void main() {
  test('锚点映射到起点不晚于锚点的最后一页', () {
    final page = _page([0, 100, 220, 400]);
    expect(pageIndexForAnchor(page, 0), 0);
    expect(pageIndexForAnchor(page, 99), 0);
    expect(pageIndexForAnchor(page, 100), 1);
    expect(pageIndexForAnchor(page, 300), 2);
    expect(pageIndexForAnchor(page, 5000), 3);
  });

  test('无偏移的旧布局与无效锚点返回 null', () {
    expect(pageIndexForAnchor(_page([0, 0, 0]), 50), isNull);
    expect(pageIndexForAnchor(_page([0, 100]), -1), isNull);
    expect(pageIndexForAnchor(_page([]), 10), isNull);
  });

  test('book JSON 保留锚点，缺省为 -1', () {
    expect(Book(id: 'b').anchorOffset, -1);
    final restored = Book.fromJson(Book(id: 'b', anchorOffset: 128).toJson());
    expect(restored.anchorOffset, 128);
  });
}
