import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/local/local_import_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('parseLocalTxtFile', () {
    test('reads, decodes and parses a UTF-8 TXT file', () async {
      final dir = await Directory.systemTemp.createTemp('langhuan-import-');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, '测试书.txt');
      await File(
        path,
      ).writeAsString('书名：测试书\n作者：测试作者\n\n第一章 开始\n正文一\n\n第二章 继续\n正文二\n');

      final result = parseLocalTxtFile(
        LocalTxtSource(path: path, fileName: '测试书.txt'),
      );

      expect(result.parsed.title, '测试书');
      expect(result.parsed.author, '测试作者');
      expect(result.parsed.chapters, hasLength(2));
      expect(result.parsed.chapters.first.title, '第一章 开始');
      expect(result.byteLength, greaterThan(0));
      expect(result.fingerprint, isNotEmpty);
    });

    test('fingerprint is stable for the same bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(fnv1aHex(bytes), fnv1aHex(Uint8List.fromList(bytes)));
      expect(
        fnv1aHex(bytes),
        isNot(fnv1aHex(Uint8List.fromList([1, 2, 3, 4, 6]))),
      );
    });

    test('empty file still yields one fallback chapter', () async {
      final dir = await Directory.systemTemp.createTemp('langhuan-empty-');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, '空文件.txt');
      await File(path).writeAsBytes(const []);

      final result = parseLocalTxtFile(
        LocalTxtSource(path: path, fileName: '空文件.txt'),
      );

      expect(result.parsed.chapters, hasLength(1));
      expect(result.parsed.chapters.first.body, '（文件没有内容）');
    });
  });
}
