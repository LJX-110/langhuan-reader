import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/rule/analyze_rule.dart';

/// Legado template syntax: `{{rule}}` interpolation, `{rule}` optional
/// segments and `##regex##$1` group replacement (中文万维 / 第一版主 style).
void main() {
  group('{{}} interpolation', () {
    test('URL template with JSON map scope', () {
      final rule = AnalyzeRule(
        content: jsonEncode({
          'list': [
            {'id': 42, 'name': 'A'},
          ],
        }),
        baseUrl: 'https://cxb-pro.cread.com',
        isJson: true,
      );
      final item = {'id': 42, 'name': 'A'};
      expect(
        rule.getString(
          r'https://readbook-service-freebook.cread.com/cx/bookDetailYS'
          r'?bookid={{$.id}}',
          scope: item,
        ),
        'https://readbook-service-freebook.cread.com/cx/bookDetailYS'
        '?bookid=42',
      );
    });

    test('multiple interpolations with ## inside', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      final item = {
        'lastUpdateChapterName': '第一章',
        'lastUpdateChapterDate': '2022-12-04 12:00',
      };
      expect(
        rule.getString(
          r'{{$.lastUpdateChapterName}} • {{$.lastUpdateChapterDate## .*}}',
          scope: item,
        ),
        '第一章 • 2022-12-04',
      );
    });

    test('empty interpolation collapses but keeps literal text', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      expect(
        rule.getString(r'id=[[{{$.missing}}]]', scope: {'a': 1}),
        'id=[[]]',
      );
    });
  });

  group('中文万维 rule shapes', () {
    // Real source: ruleExplore.bookList = "$.dataList",
    // bookUrl = "https://.../bookDetailYS?bookid={{$.bookid}}".
    // Before {{}} support every item was dropped as "no usable bookUrl".
    test('explore payload yields a concrete book url per item', () {
      final payload = jsonEncode({
        'dataList': [
          {'bookid': 900001, 'newBookName': '权力法则', 'authorName': '某人'},
          {'bookid': 900002, 'newBookName': '卧虎', 'authorName': '另一人'},
        ],
      });
      final rule = AnalyzeRule(
        content: payload,
        baseUrl: 'https://cxb-pro.cread.com',
        isJson: true,
      );
      final items = rule.getList(r'$.dataList');
      expect(items, hasLength(2));

      final urls = items
          .map(
            (item) => rule.getString(
              r'https://readbook-service-freebook.cread.com/cx/bookDetailYS'
              r'?bookid={{$.bookid}}',
              scope: item,
            ),
          )
          .toList();
      expect(urls, [
        'https://readbook-service-freebook.cread.com/cx/bookDetailYS'
            '?bookid=900001',
        'https://readbook-service-freebook.cread.com/cx/bookDetailYS'
            '?bookid=900002',
      ]);
    });

    test('kind join + replacement keeps readable output', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      final item = {'grade': '8.5', 'categoryName': '都市', 'bookStatue': '01'};
      final kind = rule.getString(
        r'{$.grade}分&&$.categoryName&&连载中{$.bookStatue}已完结'
        r'##连载中03|01已完结',
        scope: item,
      );
      expect(kind, contains('都市'));
      expect(kind, contains('8.5分'));
    });

    test('tocUrl template resolves against book info json', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      expect(
        rule.getString(
          r'https://readbook-service-freebook.cread.com/cx/itf/getvolume'
          r'?bookId={{$.data.bookVo.bookId}}',
          scope: {
            'data': {
              'bookVo': {'bookId': 777},
            },
          },
        ),
        'https://readbook-service-freebook.cread.com/cx/itf/getvolume'
            '?bookId=777',
      );
    });
  });

  group('{} optional segments', () {
    test('keeps value when present, drops segment when empty', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      expect(
        rule.getString(r'{$.grade}分', scope: {'grade': '8.5'}),
        '8.5分',
      );
      // Only the braces content is optional; literal text stays (Legado).
      expect(rule.getString(r'{$.grade}分', scope: {'grade': ''}), '分');
    });

    test('&& join keeps template parts', () {
      final rule = AnalyzeRule(
        content: '{}',
        baseUrl: 'https://x.com',
        isJson: true,
      );
      final item = {
        'grade': '8.5',
        'categoryName': '玄幻',
        'bookStatue': '01',
      };
      expect(
        rule.getString(
          r'{$.grade}分&&$.categoryName&&连载中{$.bookStatue}已完结',
          scope: item,
        ),
        '8.5分 玄幻 连载中01已完结',
      );
    });
  });

  group('## group replacement', () {
    test(r'$1 / $2 expand against capture groups', () {
      final rule = AnalyzeRule(
        content: '<a class="x" href="/files/12/345/"></a>',
        baseUrl: 'https://www.12bz.net',
      );
      expect(
        rule.getString(
          r'.x@href##.*/(\d+)/(\d+)/##http://www.12bz.net/files/article/'
          r'image/$1/$2/$2s.jpg',
        ),
        'http://www.12bz.net/files/article/image/12/345/345s.jpg',
      );
    });

    test('replacement without groups still deletes match', () {
      final rule = AnalyzeRule(
        content: '<span class="k">[连载]</span>',
        baseUrl: 'https://x.com',
      );
      expect(rule.getString(r'.k@text##\[|\]'), '连载');
    });
  });
}
