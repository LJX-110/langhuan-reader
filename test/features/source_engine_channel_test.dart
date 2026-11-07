import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/net/native_cookie_cache.dart';
import 'package:langhuan/features/sources/engine/source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/source_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('langhuan/engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  BookSource source() => BookSource(
    bookSourceUrl: 'https://ex.com',
    bookSourceName: '测试源',
    rawJson: jsonEncode({
      'bookSourceUrl': 'https://ex.com',
      'bookSourceName': '测试源',
    }),
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('search maps hits, wordCount and pagination cursor', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'search');
      expect(call.arguments['keyword'], '斗破');
      expect(call.arguments['page'], 1);
      return jsonEncode({
        'ok': true,
        'hits': [
          {
            'name': '斗破苍穹',
            'author': '天蚕土豆',
            'bookUrl': 'https://ex.com/book/1',
            'wordCount': '100万',
            'kind': '玄幻',
          },
        ],
        'hasNextPage': true,
        'nextPageUrl': 'https://ex.com/search?page=2',
      });
    });

    final report = await SourceEngine.instance.searchWithReport(
      source(),
      '斗破',
      1,
    );
    expect(report.hits.single.name, '斗破苍穹');
    expect(report.hits.single.wordCount, '100万');
    expect(report.hasNextPage, isTrue);
    expect(report.nextPageUrl, 'https://ex.com/search?page=2');
  });

  test('explorePage returns cursor', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'explore');
      expect(call.arguments['key'], 'https://ex.com/explore');
      return jsonEncode({
        'ok': true,
        'hits': [
          {'name': '书', 'bookUrl': 'https://ex.com/b/1'},
        ],
        'hasNextPage': false,
        'nextPageUrl': '',
      });
    });

    final result = await SourceEngine.instance.explorePage(
      source(),
      'https://ex.com/explore',
    );
    expect(result.hits.single.name, '书');
    expect(result.hasNextPage, isFalse);
  });

  test('结构化错误码转成可行动文案，并回发 cancel', () async {
    var cancelled = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cancelled = call.arguments['requestId'] as String;
        return true;
      }
      throw PlatformException(
        code: 'engine_network',
        message: 'https://ex.com/x?token=secret',
      );
    });

    await expectLater(
      SourceEngine.instance.toc(source(), 'https://ex.com/toc'),
      throwsA(
        isA<SourceStageError>().having(
          (e) => e.detail,
          'detail',
          '网络不可用，检查网络或换个书源',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isNotEmpty);
  });

  test('convertChinese forwards text + script flag', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'convertChinese');
      expect(call.arguments['text'], '龙');
      expect(call.arguments['traditional'], isTrue);
      return jsonEncode({'ok': true, 'text': '龍'});
    });

    final result = await SourceEngine.instance.convertChinese(
      '龙',
      traditional: true,
    );
    expect(result, '龍');
  });

  test('cookie 回包写入只读缓存，clearCookies 清空', () async {
    NativeCookieCache.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'cookie':
          expect(call.arguments['url'], 'https://ex.com/book/1');
          return jsonEncode({'ok': true, 'cookie': 'sid=abc'});
        case 'clearCookies':
          return jsonEncode({'ok': true});
        default:
          fail('unexpected ${call.method}');
      }
    });

    final header = await SourceEngine.instance.cookieHeader(
      'https://ex.com/book/1',
    );
    expect(header, 'sid=abc');
    expect(NativeCookieCache.headerForUrl('https://ex.com/other'), 'sid=abc');

    await SourceEngine.instance.clearCookies();
    expect(NativeCookieCache.headerForUrl('https://ex.com/other'), isNull);
  });

  test('facade error becomes SourceStageError', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'bookInfo');
      return jsonEncode({'ok': false, 'error': '规则不兼容'});
    });

    expect(
      () => SourceEngine.instance.bookInfo(source(), 'https://ex.com/b/1'),
      throwsA(
        isA<SourceStageError>().having(
          (e) => e.detail,
          'detail',
          contains('规则不兼容'),
        ),
      ),
    );
  });
}
