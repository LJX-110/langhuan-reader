import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/engine/native_engine_bridge.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

/// Network chapter body fetch. Bulk download lives in [DownloadCenter],
/// which reuses [fetchBody] as its per-chapter network step.
class ChapterDownloadService {
  ChapterDownloadService({required this.engine, required this.chapters});

  final BookSourceEngine engine;
  final ChapterRepository chapters;

  /// Fetch plain text for one chapter URL via the active source.
  Future<String> fetchBody({
    required BookSource? source,
    required List<ChapterTocEntry> toc,
    required String chapterId,
    int? idx,
    String bookUrl = '',
    String bookName = '',
  }) async {
    if (source == null) {
      return '书源不存在，请重新搜索添加或换源';
    }
    var resolvedIdx = idx;
    String chapterUrl = '';
    if (idx != null && idx >= 0 && idx < toc.length) {
      chapterUrl = toc[idx].url;
    } else {
      for (var i = 0; i < toc.length; i++) {
        if (toc[i].id == chapterId) {
          chapterUrl = toc[i].url;
          resolvedIdx = i;
          break;
        }
      }
    }
    if (chapterUrl.isEmpty) {
      return '章节地址为空，请重新加载目录';
    }
    final logUrl = Redact.forLog(chapterUrl);
    try {
      AppLog.d('Read', 'fetch content idx=$idx url=$logUrl');
      // 原生引擎优先（默认开）：失败即回落 Dart 引擎。
      final inToc = resolvedIdx != null &&
          resolvedIdx >= 0 &&
          resolvedIdx < toc.length;
      // 下一章（跳过卷标题行：url 为空的分组行）：多页正文的边界闸，
      // 引擎据此避免把下一章正文并进本章（见 BookSourceEngine.content）。
      final nextChapterUrl = inToc ? _nextChapterUrl(toc, resolvedIdx) : '';
      final native = await NativeEngineBridge.content(
        source: source,
        chapterUrl: chapterUrl,
        bookUrl: bookUrl,
        bookName: bookName,
        chapterTitle: inToc ? toc[resolvedIdx].title : '',
        chapterIndex: resolvedIdx ?? 0,
        nextChapterUrl: nextChapterUrl,
        totalChapterNum: toc.length,
      );
      if (native != null) {
        AppLog.d('Read', 'content ok (native) idx=$idx len=${native.length}');
        return native;
      }
      final content = await engine.content(
        source,
        chapterUrl,
        nextChapterUrl: nextChapterUrl,
      );
      if (content.isEmpty) {
        AppLog.w('Read', 'empty content idx=$idx url=$logUrl');
        return '章节内容加载失败，请检查书源或换源后重试';
      }
      AppLog.d('Read', 'content ok idx=$idx len=${content.length}');
      return content;
    } catch (e, st) {
      AppLog.e(
        'Read',
        'content failed idx=$idx url=$logUrl',
        error: e,
        stackTrace: st,
      );
      // Raw exceptions can embed the full request URL (tokens included);
      // details stay in the log, the UI only needs the actionable message.
      return '章节内容加载失败，请检查书源或换源后重试';
    }
  }

  /// TOC 中 [from] 之后第一个有 URL 的章节（跳过卷标题行）。
  String _nextChapterUrl(List<ChapterTocEntry> toc, int from) {
    for (var i = from + 1; i < toc.length; i++) {
      final url = toc[i].url.trim();
      if (url.isNotEmpty) return url;
    }
    return '';
  }
}
