import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/features/local/txt_book_parser.dart';
import 'package:langhuan/features/sources/util/book_id.dart';

class LocalImportResult {
  const LocalImportResult(this.book, this.chapterCount);

  final Book book;
  final int chapterCount;
}

/// Sendable input for [parseLocalTxtFile].
@immutable
class LocalTxtSource {
  const LocalTxtSource({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

/// Sendable output of [parseLocalTxtFile].
@immutable
class LocalTxtParseResult {
  const LocalTxtParseResult({
    required this.parsed,
    required this.byteLength,
    required this.fingerprint,
  });

  final ParsedTxtBook parsed;
  final int byteLength;
  final String fingerprint;
}

/// Read, decode, parse and fingerprint a TXT file.
///
/// Top-level so the whole CPU-heavy part runs in a background isolate; the
/// sqflite writes stay on the main isolate in [LocalImportService].
LocalTxtParseResult parseLocalTxtFile(LocalTxtSource source) {
  final bytes = File(source.path).readAsBytesSync();
  return LocalTxtParseResult(
    parsed: TxtBookParser.parse(
      fileName: source.fileName,
      text: decodeTxtBytes(bytes),
    ),
    byteLength: bytes.length,
    fingerprint: fnv1aHex(bytes),
  );
}

/// FNV-1a 64-bit hex, used only for a stable local book id.
String fnv1aHex(Uint8List bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Imports a TXT file into the existing books/chapters tables.
class LocalImportService {
  LocalImportService({BookRepository? books, ChapterRepository? chapters})
    : _books = books ?? BookRepository.instance,
      _chapters = chapters ?? ChapterRepository.instance;

  static const String sourceUrl = 'local://txt';

  final BookRepository _books;
  final ChapterRepository _chapters;

  Future<LocalImportResult> importFile(PlatformFile file) async {
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const FormatException('无法读取文件路径');
    }
    final fileName = file.name.isNotEmpty ? file.name : p.basename(path);
    final parsed = await compute(
      parseLocalTxtFile,
      LocalTxtSource(path: path, fileName: fileName),
    );
    final id = makeBookKey(
      sourceUrl,
      '$fileName|${parsed.byteLength}|${parsed.fingerprint}',
    );
    final existing = await _books.getById(id);
    final now = DateTime.now();
    final chapters = parsed.parsed.chapters;

    final book = Book(
      id: id,
      name: parsed.parsed.title,
      author: parsed.parsed.author.isEmpty ? '本地' : parsed.parsed.author,
      coverUrl: '',
      category: '本地',
      description: 'TXT · ${chapters.length} 章',
      readingChapter: existing?.readingChapter ?? chapters.first.title,
      latestChapter: chapters.last.title,
      chapterIndex: existing?.chapterIndex ?? 0,
      pageIndex: existing?.pageIndex ?? 0,
      scrollOffset: existing?.scrollOffset ?? 0,
      sortTime: existing?.sortTime ?? 0,
      updatedAt: now.toIso8601String(),
      sourceUrl: sourceUrl,
      bookUrl: path,
      originName: '本地导入',
    );

    await _books.upsert(book);
    await _chapters.replaceLocalChapters(
      book.id,
      chapters,
      sourceUrl: sourceUrl,
    );
    return LocalImportResult(book, chapters.length);
  }
}
