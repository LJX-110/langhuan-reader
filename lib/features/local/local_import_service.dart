import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
    final bytes = await File(path).readAsBytes();
    final text = decodeTxtBytes(bytes);
    final fileName = file.name.isNotEmpty ? file.name : p.basename(path);
    final parsed = TxtBookParser.parse(fileName: fileName, text: text);
    final fingerprint = _fnv1a(bytes);
    final id = makeBookKey(sourceUrl, '$fileName|${bytes.length}|$fingerprint');
    final existing = await _books.getById(id);
    final now = DateTime.now();

    final book = Book(
      id: id,
      name: parsed.title,
      author: parsed.author.isEmpty ? '本地' : parsed.author,
      coverUrl: '',
      category: '本地',
      description: 'TXT · ${parsed.chapters.length} 章',
      readingChapter: existing?.readingChapter ?? parsed.chapters.first.title,
      latestChapter: parsed.chapters.last.title,
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
      parsed.chapters,
      sourceUrl: sourceUrl,
    );
    return LocalImportResult(book, parsed.chapters.length);
  }

  String _fnv1a(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
