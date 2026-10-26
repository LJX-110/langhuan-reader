import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/util/title_format.dart';

void main() {
  group('normalizeTitle', () {
    test('cleans html entities, tags and whitespace', () {
      expect(normalizeTitle('  第一章&nbsp;开始  '), '第一章 开始');
      expect(normalizeTitle('&#31532;一章'), '第一章');
      expect(normalizeTitle('<em>第一章</em> 初入'), '第一章 初入');
      expect(normalizeTitle('第\u3000一章'), '第 一章');
      expect(normalizeTitle('第\u200B一章'), '第一章');
    });

    test('trims separator noise without touching numbering', () {
      expect(normalizeTitle('- 第一章 -'), '第一章');
      expect(normalizeTitle('· 第一卷 少年游'), '第一卷 少年游');
      expect(normalizeTitle('第123章：风起'), '第123章：风起');
      expect(normalizeTitle('   '), '');
    });
  });

  group('titleWithoutVolume', () {
    test('drops a duplicated volume prefix', () {
      expect(titleWithoutVolume('第一卷 第一章 初入', '第一卷'), '第一章 初入');
      expect(titleWithoutVolume('第一章 初入', '第一卷'), '第一章 初入');
      expect(titleWithoutVolume('第一卷', '第一卷'), '第一卷');
    });
  });

  group('displayReadingTitle', () {
    test('is chapter-only by default', () {
      expect(
        displayReadingTitle('第一章 初入江湖', volume: '第一卷 少年游'),
        '第一章 初入江湖',
      );
    });

    test('falls back to 第 N 章 only when the name is empty', () {
      expect(displayReadingTitle('', index: 4), '第 5 章');
      expect(displayReadingTitle('第二章', index: 4), '第二章');
      expect(displayReadingTitle(''), '');
    });

    test('composed form is available for callers that want it', () {
      expect(
        displayReadingTitle(
          '第一卷 第一章 初入',
          volume: '第一卷',
          withVolume: true,
        ),
        '第一卷 · 第一章 初入',
      );
    });
  });
}
