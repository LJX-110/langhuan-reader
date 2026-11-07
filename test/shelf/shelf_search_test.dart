import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';

void main() {
  test('书架内联搜索按书名 / 作者过滤', () {
    expect(bookMatchesShelfQuery(Book(name: '斗破苍穹'), '斗破'), isTrue);
    expect(bookMatchesShelfQuery(Book(name: '斗破苍穹'), '苍穹'), isTrue);
    expect(bookMatchesShelfQuery(Book(author: '天蚕土豆'), '土豆'), isTrue);
    expect(bookMatchesShelfQuery(Book(name: '其它书'), '斗破'), isFalse);
    expect(bookMatchesShelfQuery(Book(name: 'ABC'), 'abc'), isTrue);
  });

  test('空白查询匹配全部', () {
    expect(bookMatchesShelfQuery(Book(name: '书'), '   '), isTrue);
  });

  test('更新角标只在旧章节已知且变化时出现', () {
    expect(shelfHasNewChapter(oldLatest: '第一章', newLatest: '第二章'), isTrue);
    expect(shelfHasNewChapter(oldLatest: '第一章', newLatest: '第一章'), isFalse);
    expect(shelfHasNewChapter(oldLatest: '', newLatest: '第一章'), isFalse);
    expect(shelfHasNewChapter(oldLatest: '第一章', newLatest: ''), isFalse);
  });
}
