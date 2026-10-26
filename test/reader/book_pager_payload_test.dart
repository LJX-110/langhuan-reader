import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/reader/model/text_paginator.dart';
import 'package:langhuan/features/reader/pagination/book_pager.dart';

void main() {
  group('BookPager native payload contract', () {
    Map<String, dynamic> buildPayload() => BookPager.buildInputPayload(
      text: '第一章\n正文内容',
      fontSize: 18,
      lineHeight: 1.8,
      paragraph: 12,
      boxWidth: 360,
      boxHeight: 640,
      paddingHorizontal: 20,
    );

    test('sends canonical Rust field names only', () {
      final payload = buildPayload();

      expect(payload['paragraph_spacing'], 12);
      expect(payload['page_width'], 360);
      expect(payload['page_height'], 640);

      // Rust declares these as serde aliases. Sending both names is a
      // duplicate-field error that silently forces the Dart fallback.
      for (final alias in ['paragraph', 'box_width', 'box_height']) {
        expect(
          payload.containsKey(alias),
          isFalse,
          reason: 'serde alias "$alias" must not be sent alongside its field',
        );
      }
    });

    test('JSON payload has no duplicate or aliased keys', () {
      final encoded = jsonEncode(buildPayload());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded.keys.toSet().length, decoded.length);
      expect(encoded, contains('"paragraph_spacing"'));
      expect(encoded, contains('"page_width"'));
      expect(encoded, contains('"page_height"'));
      expect(encoded, isNot(contains('"paragraph"')));
      expect(encoded, isNot(contains('"box_width"')));
      expect(encoded, isNot(contains('"box_height"')));
    });
  });

  group('TextPaginator layout fingerprint', () {
    Map<String, dynamic> params({int engineRevision = 1}) => {
      'fontSize': 18.0,
      'lineHeight': 1.8,
      'paragraph': 10.0,
      'padH': 20.0,
      'boxW': 360.0,
      'boxH': 640.0,
      'fontFamily': 'HarmonyOSSansSC',
      'fontPath': '/fonts/test.ttf',
      'shouldJustifyHeight': false,
      'abi': 3,
      'textAlign': 'justify',
      'engineRevision': engineRevision,
    };

    test('changes when the pager layout revision changes', () {
      final paginator = TextPaginator();
      final current = paginator.layoutFingerprint(
        layoutParams: params(),
        contentLen: 128,
        contentSig: 'abc',
      );
      final next = paginator.layoutFingerprint(
        layoutParams: params(engineRevision: 2),
        contentLen: 128,
        contentSig: 'abc',
      );

      expect(current, isNot(next));
    });

    test('stays stable for identical inputs', () {
      final paginator = TextPaginator();
      final a = paginator.layoutFingerprint(
        layoutParams: params(),
        contentLen: 128,
        contentSig: 'abc',
      );
      final b = paginator.layoutFingerprint(
        layoutParams: params(),
        contentLen: 128,
        contentSig: 'abc',
      );

      expect(a, b);
    });
  });
}
