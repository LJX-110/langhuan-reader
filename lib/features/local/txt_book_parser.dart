import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:langhuan/data/entities/local_chapter.dart';
import 'package:path/path.dart' as p;

class ParsedTxtBook {
  const ParsedTxtBook({
    required this.title,
    required this.author,
    required this.chapters,
  });

  final String title;
  final String author;
  final List<LocalChapter> chapters;
}

/// Decode a TXT file as UTF-8, then GBK, then UTF-8 with replacement chars.
String decodeTxtBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  try {
    return utf8.decode(bytes);
  } catch (_) {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

class TxtBookParser {
  TxtBookParser._();

  static final RegExp _heading = RegExp(
    r'^[ \t]*(?:第[0-9零一二三四五六七八九十百千万两]+[章节回卷集部篇][^\n]{0,40}'
    r'|序章[^\n]{0,40}|楔子[^\n]{0,40}|番外[^\n]{0,40}'
    r'|Chapter[ \t]+\d+[^\n]{0,40})[ \t]*$',
    multiLine: true,
    caseSensitive: false,
  );

  static ParsedTxtBook parse({
    required String fileName,
    required String text,
  }) {
    final clean = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst('\uFEFF', '');
    final head = clean.length > 2000 ? clean.substring(0, 2000) : clean;

    final titleMatch = RegExp(
      r'^\s*书\s*名\s*[:：]\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(head);
    final authorMatch = RegExp(
      r'^\s*作\s*者\s*[:：]\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(head);

    var title = (titleMatch?.group(1) ?? p.basenameWithoutExtension(fileName))
        .trim();
    if (title.startsWith('《') && title.endsWith('》') && title.length > 2) {
      title = title.substring(1, title.length - 1);
    }
    if (title.isEmpty) title = '未命名';

    final matches = _heading.allMatches(clean).toList();
    final chapters = <LocalChapter>[];
    if (matches.isEmpty) {
      final body = clean.trim();
      chapters.add(LocalChapter('全文', body.isEmpty ? '（文件没有内容）' : body));
    } else {
      final preamble = clean.substring(0, matches.first.start).trim();
      if (preamble.length > 30) {
        chapters.add(LocalChapter('前言', preamble));
      }
      for (var i = 0; i < matches.length; i++) {
        final match = matches[i];
        final end = i + 1 < matches.length ? matches[i + 1].start : clean.length;
        final body = clean.substring(match.end, end).trim();
        final heading = match.group(0)!.trim();
        chapters.add(
          LocalChapter(
            heading.isEmpty ? '第 ${i + 1} 章' : heading,
            body.isEmpty ? '（本章无正文）' : body,
          ),
        );
      }
    }

    return ParsedTxtBook(
      title: title,
      author: authorMatch?.group(1)?.trim() ?? '',
      chapters: chapters,
    );
  }
}
