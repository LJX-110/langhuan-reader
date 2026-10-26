import 'dart:convert';

import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/import/source_import_conflict.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
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

  /// Which incoming URLs already exist locally, for the overwrite dialog.
  Future<Set<String>> existingUrls(List<String> urls) =>
      _sources.existingUrls(urls);

  /// Compare a parsed import with the full local rules before writing anything.
  Future<SourceImportConflict> inspectImport(SourceParseResult parsed) async {
    final urls = <String>{
      for (final source in parsed.sources)
        if (source.bookSourceUrl.isNotEmpty) source.bookSourceUrl,
    }.toList(growable: false);
    if (urls.isEmpty) return const SourceImportConflict();
    final existing = await _sources.getByUrls(urls);
    return buildSourceImportConflict(
      incoming: parsed.sources,
      existing: existing,
    );
  }

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
    final report = await testSourceSearch(source, '测试');
    if (report == null) return;
    BotToast.showText(text: '${report.label}：${report.summary}');
  }

  /// Single-source test search with a user-supplied keyword.
  ///
  /// Health treats "no result" as reachable: the site answered, the keyword
  /// just did not match. Rule/parse/network/timeout failures store -1.
  Future<SourceSearchReport?> testSourceSearch(
    BookSource source,
    String keyword,
  ) async {
    final key = keyword.trim();
    if (key.isEmpty) {
      BotToast.showText(text: '请输入搜索关键词');
      return null;
    }
    BotToast.showText(text: '正在测试「${source.bookSourceName}」…');
    final hydrated = await _sources.getByUrl(source.bookSourceUrl) ?? source;
    final report = await BookSourceEngine().searchWithReport(hydrated, key, 1);
    source.respondTime = report.reachable ? report.elapsedMs : -1;
    source.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
    await _sources.updateHealth(
      source.bookSourceUrl,
      respondTime: source.respondTime,
      lastCheckTime: source.lastCheckTime,
    );
    notifyListeners();
    return report;
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

  /// 批量移动分组：把 [urls] 的 bookSourceGroup 替换为 [group]（空 = 清空）。
  Future<void> setGroup(List<String> urls, String group) async {
    if (urls.isEmpty) return;
    final value = group.trim();
    await _sources.updateGroups(urls, value);
    final set = urls.toSet();
    for (final s in sources) {
      if (set.contains(s.bookSourceUrl)) s.bookSourceGroup = value;
    }
    notifyListeners();
  }

  /// Export only [urls], with full rule payloads, in the given order.
  Future<String> exportSelected(List<String> urls) async {
    final picked = <BookSource>[];
    for (final url in urls) {
      final full = await _sources.getByUrl(url);
      if (full != null) picked.add(full);
    }
    final list = picked.map((s) {
      if (s.rawJson.isNotEmpty) {
        try {
          return jsonDecode(s.rawJson);
        } catch (_) {}
      }
      return s.toLegadoJson();
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
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
      '成功导入 ${stats.total} 个书源'
          '（新增 ${stats.inserted}，更新 ${stats.updated}，'
          '保留本地 ${stats.preserved}）',
    ];
    if (duplicatesInBatch > 0) {
      parts.add('合并重复 $duplicatesInBatch');
    }
    if (skipped > 0) {
      parts.add('跳过 $skipped');
    }
    return parts.join('，');
  }

  /// Commit an already-fetched repository payload.
  Future<SourceUpsertStats> importParsed(
    SourceParseResult parsed, {
    bool agreed = false,
    bool silent = false,
    bool overwriteExistingRules = false,
  }) async {
    if (!agreed) {
      throw StateError('请先确认书源使用声明');
    }
    if (parsed.sources.isEmpty) {
      if (!silent) BotToast.showText(text: '未解析到有效书源');
      return const SourceUpsertStats(inserted: 0, updated: 0);
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
      return const SourceUpsertStats(inserted: 0, updated: 0);
    }
    final stats = await _commitImport(
      parsed,
      overwriteExistingRules: overwriteExistingRules,
    );
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
    return stats;
  }

  Future<SourceUpsertStats> _commitImport(
    SourceParseResult parsed, {
    required bool overwriteExistingRules,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = parsed.sources;
    for (final source in all) {
      source.lastUpdateTime = now;
    }
    if (overwriteExistingRules) {
      // One transaction: a mid-batch failure rolls the whole overwrite back,
      // so the local source list cannot end up half repository / half local.
      final stats = await _sources.overwriteAllWithRollback(all);
      for (final source in all) {
        source.rawJson = '';
      }
      all.clear();
      return stats;
    }

    // Default path: the repository keeps existing rows and inserts new ones
    // inside one transaction, so a failure cannot leave a half-imported batch.
    final stats = await _sources.upsertAllWithStats(all);
    for (final source in all) {
      source.rawJson = '';
    }
    all.clear();
    return stats;
  }

  /// Export from DB in chunks (list cache has no `raw_json`).
  Future<String> exportAll() async {
    final maps = await _sources.loadAllRawJsonMaps();
    return const JsonEncoder.withIndent('  ').convert(maps);
  }

  Future<BookSource?> findByUrl(String url) => _sources.getByUrl(url);
}
