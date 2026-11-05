import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:langhuan/features/sources/engine/native_engine_bridge.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

void main() {
  test('buildBookJson 字段名对齐 Kotlin 实体、空值给 null', () {
    final m = NativeEngineBridge.buildBookJson(
      bookUrl: 'https://a.com/b/1',
      tocUrl: 'https://a.com/b/1/toc',
      origin: 'https://a.com',
      originName: '测试源',
      name: '书',
      kind: '',
      coverUrl: '',
      totalChapterNum: 12,
    );
    expect(m['bookUrl'], 'https://a.com/b/1');
    expect(m['tocUrl'], 'https://a.com/b/1/toc');
    expect(m['origin'], 'https://a.com');
    expect(m['originName'], '测试源');
    expect(m['name'], '书');
    expect(m['kind'], isNull);
    expect(m['coverUrl'], isNull);
    expect(m['totalChapterNum'], 12);
    expect(jsonEncode(m), isNotEmpty);
  });

  test('parseStagePayload：ok=false / null 一律返回 null', () {
    expect(
      NativeEngineBridge.parseStagePayload({'ok': false, 'error': 'x'}, 't'),
      isNull,
    );
    expect(NativeEngineBridge.parseStagePayload(null, 't'), isNull);
    expect(
      NativeEngineBridge.parseStagePayload({'ok': true}, 't'),
      isNotNull,
    );
  });

  test('sourceJson：rawJson 为空时返回 null（回落 Dart 引擎）', () {
    final s = BookSource(bookSourceUrl: 'https://a.com');
    expect(NativeEngineBridge.sourceJson(s), isNull);
    s.rawJson = '{"bookSourceUrl":"https://a.com"}';
    expect(NativeEngineBridge.sourceJson(s), isNotNull);
  });
}
