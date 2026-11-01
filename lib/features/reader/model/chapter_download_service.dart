import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/core/utils/redact.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
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
  }) async {
    if (source == null) {
      return '书源不存在，请重新搜索添加或换源';
    }
    String chapterUrl = '';
    if (idx != null && idx >= 0 && idx < toc.length) {
      chapterUrl = toc[idx].url;
    } else {
      for (final c in toc) {
        if (c.id == chapterId) {
          chapterUrl = c.url;
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
      final content = await engine.content(source, chapterUrl);
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

}
