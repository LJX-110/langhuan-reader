import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/design/components/archive_header.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/search/search_model.dart';

class Search extends ConsumerStatefulWidget {
  final String type;
  final String name;

  /// When true, hosted inside [MainShell] — no back button, keep state.
  final bool embedded;

  const Search(this.type, this.name, {super.key, this.embedded = false});

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
    if (!widget.embedded) {
      try {
        searchModel.clear();
      } catch (_) {}
      controller.dispose();
    }
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
        bottom: false,
        child: Column(
          children: [
            _searchBar(context),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          if (!widget.embedded)
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
                autofocus: !widget.embedded && widget.name.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (word) => searchModel.search(word),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, height: 1.2),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: '搜索书名或作者',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMute,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.inkMute,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 38),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 17,
                            color: AppColors.inkMute,
                          ),
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
            onPressed: () {
              if (widget.embedded) {
                controller.clear();
                searchModel.reset();
                setState(() {});
              } else {
                Navigator.of(context).maybePop();
              }
            },
            child: Text(widget.embedded ? '清除' : '取消'),
          ),
        ],
      ),
    );
  }

  Widget _suggestionView(BuildContext context, SearchModel model) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ArchiveLabel(
            '01 / 全域搜索',
            padding: EdgeInsets.zero,
          ),
          const ArchiveTitle(
            title: '搜索',
            subtitle: '搜索全部已启用书源，结果按书合并',
            padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
          ),
          const SizedBox(height: 22),
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
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '还没有搜索记录。试试书名、作者，或一个关键词。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.inkMute,
                ),
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
                    InkWell(
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
                          color: AppColors.paperLight.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line, width: .5),
                        ),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paperLight.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              border: Border.all(color: AppColors.line, width: .5),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '注',
                  style: TextStyle(
                    color: AppColors.seal,
                    fontFamily: AppType.serif,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '搜索只在你启用过的书源里进行。同名书会合并为一条，并标出书源数量。',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.7,
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView(BuildContext context, SearchModel model) {
    final groups = model.groups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveLabel('01 / 全域搜索'),
        ArchiveTitle(
          title: '搜索结果',
          subtitle: model.loading && groups.isEmpty
              ? '正在搜索书源…'
              : '${groups.length} 本书 · 按书合并',
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
        ),
        Expanded(
          child: _resultBody(context, model, groups),
        ),
      ],
    );
  }

  Widget _resultBody(
    BuildContext context,
    SearchModel model,
    List<SearchGroup> groups,
  ) {
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
            Text(
              progress,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkMute,
              ),
            ),
          ],
        ),
      );
    }

    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 110),
          Center(
            child: Text(
              '暂无搜索结果',
              style: TextStyle(fontSize: 13, color: AppColors.inkMute),
            ),
          ),
        ],
      );
    }

    final showFooter = model.loading || model.noMore;
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
            return SizedBox(
              height: 54,
              child: Center(
                child: model.loading
                    ? const CupertinoActivityIndicator(radius: 10)
                    : const Text(
                        '到底了',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMute,
                        ),
                      ),
              ),
            );
          }
          return _resultRow(context, groups[i], model);
        },
      ),
    );
  }

  Widget _resultRow(
    BuildContext context,
    SearchGroup group,
    SearchModel model,
  ) {
    final item = group.item;
    final sourceLabel = group.sourceCount > 1
        ? '${group.sourceCount} 个书源'
        : (item.sourceName.isEmpty ? '书源' : item.sourceName);
    return InkWell(
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
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.line, width: .5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.coverRadius),
              child: PicWidget(item.coverUrl, width: 58, height: 84),
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
                    style: const TextStyle(
                      fontFamily: AppType.serif,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.author.isEmpty ? '未知作者' : item.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMute,
                    ),
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
                          color: AppColors.qingmo.withValues(alpha: .075),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          sourceLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.qingmo,
                          ),
                        ),
                      ),
                      if (group.sourceNames.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            group.sourceNames.take(2).join(' / '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.inkMute,
                            ),
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
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMute,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
