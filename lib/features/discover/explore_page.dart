import 'dart:convert';

import 'package:langhuan/design/components/page_header.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/discover/explore_model.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/features/discover/explore_source_picker_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-tab discovery page driven by book-source `exploreUrl` / `ruleExplore`.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(exploreModelProvider).ensureLoaded();
    });
  }

  Future<void> _openBook(
    BuildContext context,
    ExploreModel model,
    SearchItem item,
  ) async {
    final book = await model.openDetail(item);
    if (book == null || !context.mounted) return;
    Routes.navigateTo(
      context,
      Routes.detail,
      params: {'detail': jsonEncode(book)},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final model = ref.watch(exploreModelProvider);

    // Importing / deleting sources should refresh the discover entry points
    // without needing to restart the app.
    ref.listen(sourceModelProvider, (previous, next) {
      final before =
          previous?.sources.where((s) => s.enabled && s.canExplore).length ?? 0;
      final after = next.sources.where((s) => s.enabled && s.canExplore).length;
      if (before != after) {
        ref.read(exploreModelProvider).reloadSources();
      }
    });

    return Scaffold(
      backgroundColor: dark ? AppColors.scaffoldDark : AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: '发现',
              actions: [
                IconButton(
                  tooltip: '搜索',
                  icon: const Icon(Icons.search, size: 21),
                  onPressed: () {
                    Routes.navigateTo(
                      context,
                      Routes.search,
                      params: {'type': 'book', 'name': ''},
                    );
                  },
                ),
                IconButton(
                  tooltip: '刷新书源',
                  icon: const Icon(Icons.refresh, size: 21),
                  onPressed: () => model.reloadSources(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ExploreSourceTrigger(model: model, dark: dark),
            if (model.kinds.length > 1) _KindBar(model: model, dark: dark),
            Divider(
              height: 1,
              color: dark ? AppColors.dividerDark : AppColors.divider,
            ),
            Expanded(
              child: _BookList(
                model: model,
                dark: dark,
                onOpen: (item) => _openBook(context, model, item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact bar: current explore source + count; opens picker sheet.
class _ExploreSourceTrigger extends StatelessWidget {
  final ExploreModel model;
  final bool dark;
  const _ExploreSourceTrigger({required this.model, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (model.exploreSources.isEmpty) {
      return const SizedBox.shrink();
    }
    final accent = AppColors.accentOf(context);
    final accentSoft = AppColors.accentSoftOf(context);
    final primary = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final secondary = dark ? AppColors.textMutedDark : AppColors.textSecondary;
    final active = model.activeSource;
    final name = (active?.bookSourceName.trim().isNotEmpty ?? false)
        ? active!.bookSourceName
        : (active?.bookSourceUrl ?? '选择书源');
    final count = model.exploreSources.length;

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Material(
          color: accentSoft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final sources = List.of(model.exploreSources);
              ExploreSourcePickerSheet.show(
                context,
                sources: sources,
                activeUrl: active?.bookSourceUrl,
                onSelected: (s) => model.selectSource(s),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('书源', style: TextStyle(fontSize: 12, color: secondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      // 只统计带 exploreUrl 的源；导入总量不等于可发现量，
                      // 这里写清楚，避免被当成"源丢了"。
                      '$count 个可发现',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 20, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KindBar extends StatelessWidget {
  final ExploreModel model;
  final bool dark;
  const _KindBar({required this.model, required this.dark});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);
    final unselected = dark ? AppColors.textOnDark : AppColors.textSecondary;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: model.kinds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, i) {
          final k = model.kinds[i];
          final selected =
              model.activeKind?.title == k.title &&
              model.activeKind?.url == k.url;
          return _KindTab(
            label: k.title,
            selected: selected,
            activeColor: accent,
            underlineColor: companion,
            inactiveColor: unselected,
            onTap: () => model.selectKind(k),
          );
        },
      ),
    );
  }
}

/// Text tab with a short companion-colour underline, matching the dock's
/// active marker. No filled chip: the page stays a flat list.
class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.underlineColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final Color underlineColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        splashColor: activeColor.withValues(alpha: .06),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? activeColor : inactiveColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 18 : 0,
              height: 2,
              color: underlineColor,
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final ExploreModel model;
  final bool dark;
  final Future<void> Function(SearchItem item) onOpen;
  const _BookList({
    required this.model,
    required this.dark,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final secondary = dark ? AppColors.textMutedDark : AppColors.textSecondary;
    final tertiary = dark ? const Color(0xFF8A8A8A) : AppColors.textTertiary;

    if (model.loading && model.books.isEmpty) {
      return _ExploreSkeleton(dark: dark);
    }

    if (model.books.isEmpty) {
      final error = model.error ?? '';
      final activeName = model.activeSource?.bookSourceName ?? '';
      final hasSource = model.exploreSources.isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          Text(
            error.isEmpty ? '这个分类下还没有内容' : error,
            style: TextStyle(fontSize: 14, color: secondary, height: 1.5),
          ),
          if (activeName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '当前书源：$activeName',
              style: TextStyle(fontSize: 12, color: tertiary),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => Routes.navigateTo(context, Routes.sources),
                child: const Text('书源管理'),
              ),
              if (hasSource)
                TextButton(
                  onPressed: model.loading
                      ? null
                      : () => model.loadBooks(refresh: true),
                  child: const Text('重试'),
                ),
              if (model.exploreSources.length > 1)
                TextButton(
                  onPressed: () {
                    ExploreSourcePickerSheet.show(
                      context,
                      sources: List.of(model.exploreSources),
                      activeUrl: model.activeSource?.bookSourceUrl,
                      onSelected: (s) => model.selectSource(s),
                    );
                  },
                  child: const Text('换书源'),
                ),
            ],
          ),
        ],
      );
    }

    const picW = 72.0;
    final picH = picW / .65;
    final rowH = picH + 20;
    final showFooter = model.loading || model.noMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          model.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemExtent: rowH,
        itemCount: model.books.length + (showFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= model.books.length) {
            return SizedBox(
              height: rowH,
              child: Center(
                child: model.loading
                    ? const CupertinoActivityIndicator()
                    : Text(
                        '没有更多了',
                        style: TextStyle(fontSize: 12, color: tertiary),
                      ),
              ),
            );
          }
          final item = model.books[i];
          return _BookRow(
            item: item,
            picW: picW,
            picH: picH,
            rowH: rowH,
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            onTap: () => onOpen(item),
          );
        },
      ),
    );
  }
}

class _ExploreSkeleton extends StatelessWidget {
  const _ExploreSkeleton({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final block = dark ? const Color(0xFF232323) : const Color(0xFFF2F2F2);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: 5,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 100,
              decoration: BoxDecoration(
                color: block,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 90,
                    height: 11,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 180,
                    height: 10,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final SearchItem item;
  final double picW;
  final double picH;
  final double rowH;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final VoidCallback onTap;

  const _BookRow({
    required this.item,
    required this.picW,
    required this.picH,
    required this.rowH,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: rowH,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.dividerDark
                    : AppColors.line,
                width: .5,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                child: PicWidget(
                  item.coverUrl,
                  width: picW,
                  height: picH,
                  referer: item.bookUrl,
                  title: item.name,
                  baseUrl: item.sourceUrl,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      Text(
                        item.author.isEmpty ? '未知作者' : item.author,
                        maxLines: 1,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                      Text(
                        item.description.isEmpty ? '暂无简介' : item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                      Row(
                        children: [
                          if (item.sourceName.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSoftOf(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.sourceName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accentOf(context),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.latestChapter,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: tertiary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
