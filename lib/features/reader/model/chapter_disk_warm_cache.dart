import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/reader/model/chapter_content_loader.dart';
import 'package:langhuan/features/reader/model/text_paginator.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// In-memory warm window of disk chapter body + page layout (cur±1).
class ChapterDiskWarmCache {
  ChapterDiskWarmCache({required this.chapters, required this.paginator});

  final ChapterRepository chapters;
  final TextPaginator paginator;

  final Map<String, ChapterDiskCache> _warm = {};

  Map<String, ChapterDiskCache> get map => _warm;

  void clear() => _warm.clear();

  /// Drop a single chapter snapshot (e.g. after body refresh).
  void remove(String chapterId) => _warm.remove(chapterId);

  /// Prefetch disk rows for [centerIdx] and its configured neighbors.
  ///
  /// The window is `[center - prefetchBack, center + prefetchForward]` from
  /// the reader settings (defaults 1 back / 2 forward).
  Future<void> warmAround(List<ChapterTocEntry> toc, int centerIdx) async {
    if (toc.isEmpty) return;
    final ids = <String>[];
    final from = centerIdx - ReadSetting.prefetchBack;
    final to = centerIdx + ReadSetting.prefetchForward;
    for (var i = from; i <= to; i++) {
      if (i < 0 || i >= toc.length) continue;
      final id = toc[i].id;
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;
    try {
      final map = await chapters.getChapterCaches(ids);
      _warm
        ..clear()
        ..addAll(map);
    } catch (e) {
      AppLog.w('Read', 'warm disk chapter cache failed', error: e);
    }
  }

  /// True when chapter body + fingerprinted page layout are both on disk.
  Future<bool> hasPageCache(List<ChapterTocEntry> toc, int idx) async {
    if (idx < 0 || idx >= toc.length) return false;
    final chapterId = toc[idx].id;
    try {
      final disk = await chapters.getChapterCache(chapterId);
      if (disk.body.isEmpty) return false;
      final layout = paginator.layoutParams();
      final fp = paginator.layoutFingerprint(
        layoutParams: layout,
        contentLen: disk.body.length,
        contentSig: paginator.contentSignature(disk.body),
      );
      return disk.pagesJson != null &&
          disk.pagesJson!.isNotEmpty &&
          disk.layoutFp == fp;
    } catch (_) {
      return false;
    }
  }
}
