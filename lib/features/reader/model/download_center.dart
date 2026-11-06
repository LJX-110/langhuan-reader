import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_node.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/core/utils/perf_log.dart';
import 'package:langhuan/features/reader/model/chapter_download_service.dart';
import 'package:langhuan/features/sources/engine/source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:flutter/foundation.dart';

/// 下载阶段（对齐文库 `DownloadPhase`）。
enum DownloadPhase { queued, preparing, downloading, paused, completed, failed }

/// 一本书的离线下载任务。
class BookDownload {
  BookDownload({
    required this.bookId,
    required this.bookName,
    required this.toc,
    required this.source,
    required this.startIndex,
  });

  final String bookId;
  final String bookName;

  /// 与阅读会话共享的目录对象：完成一章就把该章的 `hasBody` 置真，
  /// 目录页的「已缓存」标记随之刷新。
  final List<ChapterTocEntry> toc;
  final BookSource? source;
  final int startIndex;

  DownloadPhase phase = DownloadPhase.queued;

  /// 本轮运行已完成的章节数（暂停/继续后按剩余量重算）。
  int completed = 0;
  int total = 0;
  int failed = 0;

  /// 暂停 / 中断原因：`wifi`（仅 WiFi 拦截）或 `aborted`（连续失败）。
  String? stopReason;

  bool get active =>
      phase == DownloadPhase.queued ||
      phase == DownloadPhase.preparing ||
      phase == DownloadPhase.downloading;

  /// 是否还有可续下的章（暂停 / 失败 / 完成但带失败章节）。
  bool get resumable {
    if (active) return false;
    if (phase == DownloadPhase.paused || phase == DownloadPhase.failed) {
      return true;
    }
    return phase == DownloadPhase.completed && failed > 0;
  }

  String get label {
    switch (phase) {
      case DownloadPhase.queued:
        return '等待下载…';
      case DownloadPhase.preparing:
        return '正在准备下载…';
      case DownloadPhase.downloading:
        return '正在下载 · $completed / $total 章';
      case DownloadPhase.paused:
        return stopReason == 'wifi'
            ? '已暂停 · 仅 WiFi 模式，连接 WiFi 后可继续'
            : '已暂停 · 保留已缓存章节';
      case DownloadPhase.failed:
        return stopReason == 'aborted'
            ? '下载中断 · 连续失败已停止（已完成 $completed / $total 章）'
            : '下载失败，可重试';
      case DownloadPhase.completed:
        return failed > 0
            ? '下载完成 · $completed 章（$failed 章失败，可重试）'
            : '下载完成 · $completed 章';
    }
  }
}

/// fetch 回调签名（默认走 [ChapterDownloadService.fetchBody]）。
typedef ChapterBodyFetcher =
    Future<String> Function({
      required BookSource? source,
      required List<ChapterTocEntry> toc,
      required String chapterId,
      int? idx,
    });

/// 离线下载中心：一次只跑一本书（队列语义，对齐文库），支持暂停 / 继续、
/// 失败统计、仅 WiFi 与清缓存。
///
/// 与 Wenku8 `OfflineNovelRepository` 的取舍：
/// - 失败不立即中断：累计 3 连败才停（对单章抽风的源更友好）；
/// - 暂停 / 继续即文库的「取消 / 继续下载」：已落库的章节不重下。
class DownloadCenter extends ChangeNotifier {
  DownloadCenter({
    ChapterBodyFetcher? fetch,
    Future<void> Function(List<ChapterNode> nodes)? saveBodies,
    Future<bool> Function()? wifiProbe,
  }) : _fetch = fetch ?? _serviceFetch,
       _saveBodies = saveBodies ?? ChapterRepository.instance.updateBodies,
       _wifiProbe = wifiProbe ?? _defaultWifiProbe;

  static final DownloadCenter instance = DownloadCenter();

  static final ChapterDownloadService _service = ChapterDownloadService(
    engine: SourceEngine.instance,
    chapters: ChapterRepository.instance,
  );

  static Future<String> _serviceFetch({
    required BookSource? source,
    required List<ChapterTocEntry> toc,
    required String chapterId,
    int? idx,
  }) => _service.fetchBody(
    source: source,
    toc: toc,
    chapterId: chapterId,
    idx: idx,
  );

  /// 仅 WiFi 探测；平台探测失败时放行（检测不可用不应卡死下载）。
  static Future<bool> _defaultWifiProbe() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return true;
    }
  }

  final ChapterBodyFetcher _fetch;
  final Future<void> Function(List<ChapterNode> nodes) _saveBodies;
  final Future<bool> Function() _wifiProbe;

  final Map<String, BookDownload> _jobs = {};
  final Queue<String> _queue = Queue();
  bool _draining = false;

  BookDownload? jobOf(String bookId) => _jobs[bookId];

  /// 入队一本书的下载（[start] 起往后）；已有活动任务时忽略重复请求。
  void start({
    required Book book,
    required List<ChapterTocEntry> toc,
    required BookSource? source,
    required int start,
  }) {
    if (toc.isEmpty) return;
    final existing = _jobs[book.id];
    if (existing?.active == true) return;
    final job = BookDownload(
      bookId: book.id,
      bookName: book.name,
      toc: toc,
      source: source,
      startIndex: start.clamp(0, toc.length - 1),
    );
    _jobs[book.id] = job;
    _queue.add(book.id);
    AppLog.i('Download', 'queued book=${book.id} start=${job.startIndex}');
    notifyListeners();
    unawaited(_drain());
  }

  /// 暂停：保留已落库的章节，当前在途请求返回后不再写入。
  void pause(String bookId) {
    final job = _jobs[bookId];
    if (job == null || !job.active) return;
    job.stopReason = null;
    job.phase = DownloadPhase.paused;
    AppLog.i(
      'Download',
      'paused book=$bookId at ${job.completed}/${job.total}',
    );
    notifyListeners();
  }

  /// 继续 / 重试：按 hasBody 重算剩余量，只下缺的。
  void resume(String bookId) {
    final job = _jobs[bookId];
    if (job == null || job.active) return;
    job.stopReason = null;
    job.failed = 0;
    job.phase = DownloadPhase.queued;
    _queue.add(bookId);
    notifyListeners();
    unawaited(_drain());
  }

  /// 丢弃任务状态（换源 / 清缓存后调用）。
  void forget(String bookId) {
    final job = _jobs.remove(bookId);
    if (job != null && job.active) {
      job.phase = DownloadPhase.paused;
    }
    notifyListeners();
  }

  bool get wifiOnlyEnabled {
    try {
      return SpUtil.getBool(PrefsKeys.downloadWifiOnly, defValue: false);
    } catch (_) {
      return false;
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeFirst();
        final job = _jobs[id];
        if (job == null || job.phase != DownloadPhase.queued) continue;
        await _run(job);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _run(BookDownload job) async {
    final perf = PerfLog.start('Download.job');
    job.phase = DownloadPhase.preparing;
    job.completed = 0;
    job.failed = 0;
    notifyListeners();

    final pending = <(int, ChapterTocEntry)>[];
    for (var i = job.startIndex; i < job.toc.length; i++) {
      final chapter = job.toc[i];
      if (!chapter.hasBody) pending.add((i, chapter));
    }
    job.total = pending.length;
    if (job.total == 0) {
      job.phase = DownloadPhase.completed;
      perf.done('book=${job.bookId} empty');
      notifyListeners();
      return;
    }
    job.phase = DownloadPhase.downloading;
    notifyListeners();

    final buffer = <ChapterNode>[];
    var consecutive = 0;
    var checked = 0;
    try {
      for (final (idx, chapter) in pending) {
        if (job.phase != DownloadPhase.downloading) break;

        // 仅 WiFi：每 10 章复查一次，掉出 WiFi 自动暂停。
        if (checked % 10 == 0) {
          final allowed = await _wifiAllowed();
          if (job.phase != DownloadPhase.downloading) break;
          if (!allowed) {
            job.stopReason = 'wifi';
            job.phase = DownloadPhase.paused;
            notifyListeners();
            break;
          }
        }
        checked++;

        final content = await _fetch(
          source: job.source,
          toc: job.toc,
          chapterId: chapter.id,
          idx: idx,
        );
        // 暂停 / 中断后到达的响应不落库（对齐文库的 late-commit 抑制）。
        if (job.phase != DownloadPhase.downloading) break;

        if (_contentOk(content)) {
          buffer.add(ChapterNode(content, chapter.id));
          chapter.hasBody = true;
          job.completed++;
          consecutive = 0;
          if (buffer.length >= 50) {
            await _flush(buffer);
          }
          notifyListeners();
        } else {
          job.failed++;
          consecutive++;
          notifyListeners();
          if (consecutive >= 3) {
            job.stopReason = 'aborted';
            job.phase = DownloadPhase.failed;
            break;
          }
        }
      }
    } finally {
      // 暂停 / 中断 / 正常结束：已取到的正文先落库，进度不丢。
      await _flush(buffer);
    }

    if (job.phase == DownloadPhase.downloading) {
      job.phase = DownloadPhase.completed;
    }
    AppLog.i(
      'Download',
      'job ${job.phase.name} book=${job.bookId} '
      'done=${job.completed}/${job.total} failed=${job.failed}',
    );
    perf.done(
      'book=${job.bookId} phase=${job.phase.name} '
      'done=${job.completed}/${job.total} failed=${job.failed}',
    );
    notifyListeners();
  }

  Future<void> _flush(List<ChapterNode> buffer) async {
    if (buffer.isEmpty) return;
    final nodes = List<ChapterNode>.of(buffer);
    buffer.clear();
    try {
      await _saveBodies(nodes);
    } catch (e) {
      AppLog.w('Download', 'save bodies failed', error: e);
    }
  }

  Future<bool> _wifiAllowed() async {
    if (!wifiOnlyEnabled) return true;
    return _wifiProbe();
  }

  static bool _contentOk(String content) =>
      content.isNotEmpty &&
      !content.startsWith('章节内容加载失败') &&
      !content.startsWith('书源不存在') &&
      !content.startsWith('章节地址为空');
}
