import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/features/local/txt_book_parser.dart';

void main() {
  test('parses title, author and chapter headings', () {
    final parsed = TxtBookParser.parse(
      fileName: '山月记.txt',
      text: '''
书名：山月记
作者：中岛敦

第一章 夜航
第一段正文。

第二章 归途
第二段正文。
''',
    );

    expect(parsed.title, '山月记');
    expect(parsed.author, '中岛敦');
    expect(parsed.chapters, hasLength(2));
    expect(parsed.chapters[0].title, '第一章 夜航');
    expect(parsed.chapters[0].body, '第一段正文。');
    expect(parsed.chapters[1].title, '第二章 归途');
  });

  test('falls back to one chapter when no headings exist', () {
    final parsed = TxtBookParser.parse(fileName: '短篇.txt', text: '只有一段正文。');

    expect(parsed.title, '短篇');
    expect(parsed.chapters, hasLength(1));
    expect(parsed.chapters.single.title, '全文');
  });

  test('decodes GBK bytes', () {
    final bytes = Uint8List.fromList(gbk.encode('第一章 夜航\n正文'));
    expect(decodeTxtBytes(bytes), contains('第一章 夜航'));
  });
}
