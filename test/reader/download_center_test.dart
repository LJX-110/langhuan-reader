import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/chapter_node.dart';
import 'package:langhuan/data/entities/chapter_toc_entry.dart';
import 'package:langhuan/features/reader/model/download_center.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ChapterTocEntry> _toc(int n, {String prefix = 'c'}) => [
  for (var i = 0; i < n; i++)
    ChapterTocEntry(
      id: '$prefix$i',
      title: '第${i + 1}章',
      url: 'https://ex.com/$prefix$i',
    ),
];

/// 让事件循环跑几轮，等 DownloadCenter 的异步链收束。
Future<void> _settle() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  test('整段下载：落库、计数与 hasBody 全部置真', () async {
    final saved = <ChapterNode>[];
    final toc = _toc(5);
    final center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async => '正文-$chapterId',
      saveBodies: (nodes) async => saved.addAll(nodes),
      wifiProbe: () async => true,
    );

    center.start(
      book: Book(id: 'b1', name: '书一'),
      toc: toc,
      source: null,
      start: 0,
    );
    await _settle();

    final job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.completed);
    expect(job.completed, 5);
    expect(job.failed, 0);
    expect(saved, hasLength(5));
    expect(toc.every((c) => c.hasBody), isTrue);
  });

  test('暂停保留进度；继续只补缺的章节', () async {
    final saved = <ChapterNode>[];
    final toc = _toc(5);
    var calls = 0;
    late DownloadCenter center;
    center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async {
            calls++;
            // 第二章取回前暂停：在途响应不落库。
            if (calls == 2) center.pause('b1');
            return '正文-$chapterId';
          },
      saveBodies: (nodes) async => saved.addAll(nodes),
      wifiProbe: () async => true,
    );

    center.start(
      book: Book(id: 'b1', name: '书一'),
      toc: toc,
      source: null,
      start: 0,
    );
    await _settle();

    var job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.paused);
    expect(job.completed, 1);
    expect(saved, hasLength(1));
    expect(toc[0].hasBody, isTrue);
    expect(toc[1].hasBody, isFalse);

    center.resume('b1');
    await _settle();

    job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.completed);
    expect(job.completed, 4);
    expect(saved, hasLength(5));
    expect(toc.every((c) => c.hasBody), isTrue);
    // 2 + 4：已缓存的章不重下。
    expect(calls, 6);
  });

  test('连续 3 章失败中断为 failed，重试后补齐', () async {
    final saved = <ChapterNode>[];
    final toc = _toc(6);
    var calls = 0;
    var fail = true;
    late DownloadCenter center;
    center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async {
            calls++;
            return fail ? '章节内容加载失败，请检查书源或换源后重试' : '正文-$chapterId';
          },
      saveBodies: (nodes) async => saved.addAll(nodes),
      wifiProbe: () async => true,
    );

    center.start(
      book: Book(id: 'b1', name: '书一'),
      toc: toc,
      source: null,
      start: 0,
    );
    await _settle();

    var job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.failed);
    expect(job.stopReason, 'aborted');
    expect(job.failed, 3);
    expect(calls, 3);
    expect(saved, isEmpty);

    fail = false;
    center.resume('b1');
    await _settle();

    job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.completed);
    expect(job.completed, 6);
    expect(toc.every((c) => c.hasBody), isTrue);
  });

  test('仅 WiFi：非 WiFi 自动暂停，WiFi 恢复后可继续', () async {
    SpUtil.putBool(PrefsKeys.downloadWifiOnly, true);
    var wifi = false;
    final toc = _toc(3);
    final center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async => '正文-$chapterId',
      saveBodies: (nodes) async {},
      wifiProbe: () async => wifi,
    );

    center.start(
      book: Book(id: 'b1', name: '书一'),
      toc: toc,
      source: null,
      start: 0,
    );
    await _settle();

    var job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.paused);
    expect(job.stopReason, 'wifi');
    expect(job.completed, 0);

    wifi = true;
    center.resume('b1');
    await _settle();

    job = center.jobOf('b1')!;
    expect(job.phase, DownloadPhase.completed);
    expect(job.completed, 3);
  });

  test('队列：一次只跑一本书，前一本完成后再开下一本', () async {
    final gate = Completer<void>();
    final done = <String>[];
    var bStarted = false;
    final center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async {
            if (chapterId.startsWith('a')) {
              await gate.future;
            } else {
              bStarted = true;
            }
            done.add(chapterId);
            return '正文-$chapterId';
          },
      saveBodies: (nodes) async {},
      wifiProbe: () async => true,
    );
    final tocA = _toc(2, prefix: 'a');
    final tocB = _toc(2, prefix: 'b');
    center.start(
      book: Book(id: 'ba', name: '甲'),
      toc: tocA,
      source: null,
      start: 0,
    );
    center.start(
      book: Book(id: 'bb', name: '乙'),
      toc: tocB,
      source: null,
      start: 0,
    );
    await _settle();

    // 甲被 gate 卡住，乙只能排队等待。
    expect(center.jobOf('ba')!.phase, DownloadPhase.downloading);
    expect(center.jobOf('bb')!.phase, DownloadPhase.queued);
    expect(bStarted, isFalse);

    gate.complete();
    await _settle();

    expect(center.jobOf('ba')!.phase, DownloadPhase.completed);
    expect(center.jobOf('bb')!.phase, DownloadPhase.completed);
    expect(bStarted, isTrue);
    expect(done, hasLength(4));
  });

  test('forget 丢弃任务状态', () async {
    final toc = _toc(2);
    final center = DownloadCenter(
      fetch:
          ({
            required BookSource? source,
            required List<ChapterTocEntry> toc,
            required String chapterId,
            int? idx,
          }) async => '正文-$chapterId',
      saveBodies: (nodes) async {},
      wifiProbe: () async => true,
    );

    center.start(
      book: Book(id: 'b1', name: '书一'),
      toc: toc,
      source: null,
      start: 0,
    );
    await _settle();
    expect(center.jobOf('b1'), isNotNull);

    center.forget('b1');
    expect(center.jobOf('b1'), isNull);
  });
}
