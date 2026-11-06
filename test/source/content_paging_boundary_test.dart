import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/util/url_join.dart';

/// 多页正文边界回归（E）：书源规则常写 `下一页||下一章@href` 兜底，
/// 最后一页会拿到「下一章」链接——必须在此停下，不能把下一章正文
/// 并进本章（否则该章内容重复、进度与书签错位）。
///
/// 判定与原生引擎 `BookContent.analyzeContent`（L106-109）一致。
void main() {
  group('多页正文边界（下一页 vs 下一章）', () {
    test('绝对地址相等 → 判定跨章，停止拼接', () {
      expect(
        BookSourceEngine.isNextChapterBoundary(
          nextPageUrl: 'https://a.com/book/2.html',
          boundaryUrl: 'https://a.com/book/2.html',
        ),
        isTrue,
      );
    });

    test('锚点差异按同址处理（站点翻页链接常带 #fragment）', () {
      expect(
        BookSourceEngine.isNextChapterBoundary(
          nextPageUrl: 'https://a.com/book/2.html#top',
          boundaryUrl: 'https://a.com/book/2.html',
        ),
        isTrue,
      );
    });

    test('同章的多页不拦截（仍要继续拼）', () {
      expect(
        BookSourceEngine.isNextChapterBoundary(
          nextPageUrl: 'https://a.com/book/1_2.html',
          boundaryUrl: 'https://a.com/book/2.html',
        ),
        isFalse,
      );
    });

    test('没有下一章信息（最后一章）不拦截', () {
      expect(
        BookSourceEngine.isNextChapterBoundary(
          nextPageUrl: 'https://a.com/book/1_2.html',
          boundaryUrl: '',
        ),
        isFalse,
      );
    });

    test('相对「下一章」先绝对化再比较', () {
      final boundary = urlJoin('https://a.com/book/1.html', '../book/2.html');
      expect(boundary, 'https://a.com/book/2.html');
      expect(
        BookSourceEngine.isNextChapterBoundary(
          nextPageUrl: 'https://a.com/book/2.html',
          boundaryUrl: boundary,
        ),
        isTrue,
      );
    });
  });
}
