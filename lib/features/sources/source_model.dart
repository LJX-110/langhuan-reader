import 'dart:convert';

import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

class SourceModel with ChangeNotifier {
  final SourceRepository _sources = SourceRepository.instance;
  List<BookSource> sources = [];
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      // Meta rows only — full raw_json must not cross MethodChannel in bulk.
      sources = await _sources.getAll();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Enabled sources without rule payloads. Prefer [hydrateSources] before engine use.
  Future<List<BookSource>> enabledSources() => _sources.getEnabled();

  Future<List<BookSource>> hydrateSources(List<BookSource> meta) {
    return _sources.getByUrls(meta.map((e) => e.bookSourceUrl).toList());
  }

  Future<int> enabledCount() => _sources.countEnabled();

  Future<void> toggle(BookSource source) async {
    source.enabled = !source.enabled;
    await _sources.setEnabled(source.bookSourceUrl, source.enabled);
    notifyListeners();
  }

  /// Run one search and store latency / failure for the health column.
  Future<void> testSource(BookSource source) async {
    if (source.searchUrl.trim().isEmpty) {
      BotToast.showText(text: '该源没有搜索规则，无法测试');
      return;
    }
    BotToast.showText(text: '正在测试「${source.bookSourceName}」…');
    final stopwatch = Stopwatch()..start();
    var ok = true;
    try {
      final hydrated = await _sources.getByUrl(source.bookSourceUrl) ?? source;
      await BookSourceEngine().search(hydrated, '测试', 1);
    } catch (_) {
      ok = false;
    }
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    source.respondTime = ok ? elapsed : -1;
    source.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
    await _sources.updateHealth(
      source.bookSourceUrl,
      respondTime: source.respondTime,
      lastCheckTime: source.lastCheckTime,
    );
    notifyListeners();
    BotToast.showText(text: ok ? '测试完成：${elapsed}ms' : '测试失败：书源不可用');
  }

  Future<void> remove(BookSource source) async {
    await _sources.delete(source.bookSourceUrl);
    sources.removeWhere((e) => e.bookSourceUrl == source.bookSourceUrl);
    notifyListeners();
  }

  Future<void> enableMany(List<String> urls) async {
    if (urls.isEmpty) return;
    await _sources.setEnabledMany(urls, true);
    final set = urls.toSet();
    for (final s in sources) {
      if (set.contains(s.bookSourceUrl)) s.enabled = true;
    }
    notifyListeners();
  }

  Future<void> disableMany(List<String> urls) async {
    if (urls.isEmpty) return;
    await _sources.setEnabledMany(urls, false);
    final set = urls.toSet();
    for (final s in sources) {
      if (set.contains(s.bookSourceUrl)) s.enabled = false;
    }
    notifyListeners();
  }

  Future<void> removeMany(List<String> urls) async {
    if (urls.isEmpty) return;
    await _sources.deleteMany(urls);
    final set = urls.toSet();
    sources.removeWhere((e) => set.contains(e.bookSourceUrl));
    notifyListeners();
  }

  String _importToast(
    SourceUpsertStats stats, {
    int skipped = 0,
    int duplicatesInBatch = 0,
  }) {
    final parts = <String>[
      '成功导入 ${stats.total} 个书源（新增 ${stats.inserted}，更新 ${stats.updated}）',
    ];
    if (duplicatesInBatch > 0) {
      parts.add('合并重复 $duplicatesInBatch');
    }
    if (skipped > 0) {
      parts.add('跳过 $skipped');
    }
    return parts.join('，');
  }

  Future<int> importJsonText(
    String text, {
    bool agreed = false,
    bool silent = false,
  }) async {
    if (!agreed) {
      throw StateError('请先确认书源使用声明');
    }
    return importParsed(
      SourceImporter.parseJson(text),
      agreed: true,
      silent: silent,
    );
  }

  Future<int> importFromUrl(
    String url, {
    bool agreed = false,
    bool silent = false,
  }) async {
    if (!agreed) {
      throw StateError('请先确认书源使用声明');
    }
    if (!silent) BotToast.showText(text: '正在下载书源…');
    return importParsed(
      await SourceImporter.fromUrl(url),
      agreed: true,
      silent: silent,
    );
  }

  /// Commit an already-fetched repository payload.
  Future<int> importParsed(
    SourceParseResult parsed, {
    bool agreed = false,
    bool silent = false,
  }) async {
    if (!agreed) {
      throw StateError('请先确认书源使用声明');
    }
    if (parsed.sources.isEmpty) {
      if (!silent) BotToast.showText(text: '未解析到有效书源');
      return 0;
    }
    final usable = parsed.sources
        .where(
          (s) =>
              s.searchUrl.trim().isNotEmpty || s.exploreUrl.trim().isNotEmpty,
        )
        .length;
    if (usable == 0) {
      if (!silent) {
        BotToast.showText(
          text:
              '这是订阅源（RSS），不能用于搜书或阅读。'
              '请从源仓库导入「书源」JSON（地址含 shuyuans/json）。',
        );
      }
      return 0;
    }
    final stats = await _commitImport(parsed);
    if (!silent) {
      await load();
      BotToast.showText(
        text: _importToast(
          stats,
          skipped: parsed.skipped,
          duplicatesInBatch: parsed.duplicatesInBatch,
        ),
      );
    }
    return stats.total;
  }

  Future<SourceUpsertStats> _commitImport(SourceParseResult parsed) async {
    final base = await _sources.count();
    final now = DateTime.now().millisecondsSinceEpoch;
    // Upsert in slices and drop each slice so peak heap stays bounded.
    const slice = 80;
    var inserted = 0;
    var updated = 0;
    final all = parsed.sources;
    for (var i = 0; i < all.length; i += slice) {
      final end = i + slice > all.length ? all.length : i + slice;
      final chunk = all.sublist(i, end);
      for (var j = 0; j < chunk.length; j++) {
        chunk[j].customOrder = base + i + j;
        chunk[j].lastUpdateTime = now;
      }
      final stats = await _sources.upsertAllWithStats(chunk);
      inserted += stats.inserted;
      updated += stats.updated;
      for (final s in chunk) {
        s.rawJson = '';
      }
    }
    all.clear();
    return SourceUpsertStats(inserted: inserted, updated: updated);
  }

  /// Export from DB in chunks (list cache has no `raw_json`).
  Future<String> exportAll() async {
    final maps = await _sources.loadAllRawJsonMaps();
    return const JsonEncoder.withIndent('  ').convert(maps);
  }

  Future<BookSource?> findByUrl(String url) => _sources.getByUrl(url);
}
