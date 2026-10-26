import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/search/search_model.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
import 'package:langhuan/features/sources/source_test_panel.dart';

class Search extends ConsumerStatefulWidget {
  final String type;
  final String name;

  const Search(this.type, this.name, {super.key});

  @override
  ConsumerState<Search> createState() => _SearchState();
}

class _SearchState extends ConsumerState<Search> {
  late SearchModel searchModel;
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchModel = ref.read(searchModelProvider);
    searchModel.loadGroupOptions();
    if (widget.type == 'book' && widget.name.isNotEmpty) {
      controller.text = widget.name;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      searchModel.context = context;
      searchModel.controller = controller;
      searchModel.historyKey = PrefsKeys.bookSearchHistory;
      searchModel.initHistory();
      if (controller.text.isNotEmpty) {
        searchModel.search(controller.text);
      }
    });
  }

  @override
  void dispose() {
    try {
      searchModel.clear();
    } catch (_) {}
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(searchModelProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _searchBar(context),
            if (model.groupOptions.length > 1) _groupChips(context, model),
            Expanded(
              child: model.showResult
                  ? _resultView(context, model)
                  : _suggestionView(context, model),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: surface.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: line, width: .5),
              ),
              child: TextField(
                controller: controller,
                autofocus: widget.name.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (word) => searchModel.search(word),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, height: 1.2),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: '搜索书名或作者',
                  hintStyle: TextStyle(fontSize: 13, color: muted),
                  prefixIcon: Icon(Icons.search, size: 18, color: muted),
                  prefixIconConstraints: const BoxConstraints(minWidth: 38),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, size: 17, color: muted),
                          onPressed: () {
                            controller.clear();
                            searchModel.reset();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// Group scope chips (全部 + each group). Switching re-runs the current
  /// keyword under the new scope.
  Widget _groupChips(BuildContext context, SearchModel model) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        children: [
          for (final group in ['', ...model.groupOptions])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  group.isEmpty ? '全部' : group,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: model.groupFilter == group,
                onSelected: (_) => model.setGroupFilter(group),
              ),
            ),
        ],
      ),
    );
  }

  Widget _suggestionView(BuildContext context, SearchModel model) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final line = theme.colorScheme.outline;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontFamily: AppType.serif,
                  fontSize: 17,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (model.searchHistory.isNotEmpty)
                TextButton(
                  onPressed: model.clearHistory,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text('清空'),
                ),
            ],
          ),
          if (model.searchHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '还没有搜索记录。试试书名、作者，或一个关键词。',
                style: TextStyle(fontSize: 12, height: 1.7, color: muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in model.searchHistory)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          controller.text = value;
                          searchModel.search(value);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? theme.colorScheme.surface
                                : AppColors.paperLight.withValues(alpha: .45),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: line, width: .5),
                          ),
                          child: Text(
                            value,
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Text(
              '搜索只在你启用过的书源里进行，同名书会合并为一条。',
              style: TextStyle(fontSize: 11.5, height: 1.7, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView(BuildContext context, SearchModel model) {
    final groups = model.groups;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              Text(
                groups.isEmpty ? '搜索结果' : '${groups.length} 本书',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (model.failures.isNotEmpty)
                InkWell(
                  onTap: () => _showDiagnostics(context, model),
                  child: Text(
                    _statusLabel(model),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else
                Text(
                  _statusLabel(model),
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ),
        ),
        Expanded(child: _resultBody(context, model, groups)),
      ],
    );
  }

  /// Header status: search progress, per-source success/failure summary, or
  /// the merge hint. Failures make it an entry point to the diagnostics sheet.
  String _statusLabel(SearchModel model) {
    if (model.loading && model.bks.isEmpty) {
      return model.softTimeoutElapsed ? '仍在搜索…' : '正在搜索…';
    }
    if (model.loading && model.fromCache) {
      return model.softTimeoutElapsed ? '缓存结果 · 仍在刷新' : '缓存结果 · 刷新中…';
    }
    if (model.failures.isNotEmpty) {
      final ok = model.reports.length - model.failures.length;
      return '成功 $ok · 失败 ${model.failures.length}';
    }
    return model.fromCache ? '缓存结果' : '按书合并';
  }

  Widget _resultBody(
    BuildContext context,
    SearchModel model,
    List<SearchGroup> groups,
  ) {
    final primary = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (model.loading && model.bks.isEmpty) {
      final progress = model.totalSources > 0
          ? '正在搜索书源…（${model.searchedSources}/${model.totalSources}）'
          : '正在搜索书源…';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 12),
            Text(progress, style: TextStyle(fontSize: 12, color: muted)),
            if (model.softTimeoutElapsed) ...[
              const SizedBox(height: 4),
              Text(
                '书源响应较慢，可继续等待或停止',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              TextButton(
                onPressed: model.stopWaiting,
                child: const Text('停止等待'),
              ),
            ],
          ],
        ),
      );
    }

    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
        children: [
          Text(
            model.allSourcesFailed ? '书源全部请求失败' : '暂无搜索结果',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.emptyHint,
            style: TextStyle(fontSize: 12, color: muted, height: 1.6),
          ),
          if (model.reports.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showDiagnostics(context, model),
                icon: const Icon(Icons.troubleshoot, size: 18),
                label: Text(
                  model.failures.isEmpty ? '查看搜索诊断' : '查看诊断并重试',
                ),
              ),
            ),
          ],
        ],
      );
    }

    final showFooter = model.loading || model.noMore || model.failedSources > 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          model.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 18),
        itemCount: groups.length + (showFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= groups.length) {
            final failedNote = !model.loading && model.failedSources > 0
                ? ' · ${model.failedSources} 个书源失败'
                : '';
            return SizedBox(
              height: 54,
              child: Center(
                child: model.loading
                    ? (model.softTimeoutElapsed
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '仍在搜索'
                                  ' (${model.searchedSources}/${model.totalSources})',
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                                TextButton(
                                  onPressed: model.stopWaiting,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    '停止等待',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            )
                          : const CupertinoActivityIndicator(radius: 10))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '到底了$failedNote',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          if (model.failures.isNotEmpty) ...[
                            const SizedBox(width: 2),
                            TextButton(
                              onPressed: () => _showDiagnostics(context, model),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                '诊断',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            );
          }
          return _resultRow(context, groups[i], model);
        },
      ),
    );
  }

  void _showDiagnostics(BuildContext context, SearchModel model) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .78,
        child: AnimatedBuilder(
          animation: model,
          builder: (context, _) {
            final muted = Theme.of(context).colorScheme.onSurfaceVariant;
            final reports = [...model.reports];
            reports.sort((a, b) {
              int rank(SourceSearchReport r) => r.failed
                  ? 0
                  : (r.issue == SourceSearchIssue.noResult ? 1 : 2);
              final byRank = rank(a).compareTo(rank(b));
              if (byRank != 0) return byRank;
              return a.sourceName.compareTo(b.sourceName);
            });
            final failures = model.failures;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '搜索诊断',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '「${model.word}」 · ${reports.length} 个书源 · '
                              '${failures.length} 个失败',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      if (failures.length > 1)
                        TextButton(
                          onPressed: () => model.retryFailedSources(),
                          child: const Text('全部重试'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: reports.isEmpty
                      ? Center(
                          child: Text(
                            '暂无诊断数据',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            12 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          itemCount: reports.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final report = reports[i];
                            final retrying = model.retryingSources.contains(
                              report.sourceUrl,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.sourceName.isEmpty
                                            ? report.sourceUrl
                                            : report.sourceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (retrying)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else if (report.failed)
                                      TextButton(
                                        onPressed: () => model.retrySource(
                                          report.sourceUrl,
                                        ),
                                        child: const Text(
                                          '重试',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () => _testSingleSource(
                                        context,
                                        model,
                                        report,
                                      ),
                                      child: const Text(
                                        '测试',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                SourceSearchReportCard(report: report),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _testSingleSource(
    BuildContext context,
    SearchModel model,
    SourceSearchReport report,
  ) {
    final name = report.sourceName.isEmpty
        ? report.sourceUrl
        : report.sourceName;
    return showSourceTestSheet(
      context: context,
      sourceName: name,
      sourceUrl: report.sourceUrl,
      initialKeyword: model.word,
      onSearch: (keyword) => model.testSingleSource(report.sourceUrl, keyword),
    );
  }

  Widget _resultRow(
    BuildContext context,
    SearchGroup group,
    SearchModel model,
  ) {
    final item = group.item;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final line = theme.colorScheme.outline;
    final accent = AppColors.accentOf(context);
    final sourceLabel = group.sourceCount > 1
        ? '${group.sourceCount} 个书源'
        : (item.sourceName.isEmpty ? '书源' : item.sourceName);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final book = await model.openDetail(item);
          if (book == null || !context.mounted) return;
          Routes.navigateTo(
            context,
            Routes.detail,
            params: {'detail': jsonEncode(book)},
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line, width: .5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                child: PicWidget(
                  item.coverUrl,
                  width: 58,
                  height: 84,
                  referer: item.bookUrl,
                  title: item.name,
                  baseUrl: item.sourceUrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppType.serif,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.author.isEmpty ? '未知作者' : item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: muted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoftOf(context, alpha: .075),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            sourceLabel,
                            style: TextStyle(fontSize: 9, color: accent),
                          ),
                        ),
                        if (group.sourceNames.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              group.sourceNames.take(2).join(' / '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 9, color: muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.latestChapter.isEmpty
                          ? '暂无章节信息'
                          : '最新章 · ${item.latestChapter}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, color: muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Icon(Icons.chevron_right, size: 18, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
