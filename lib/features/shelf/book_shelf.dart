import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/design/components/page_header.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:langhuan/features/shelf/widgets/books_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书架
class BookShelf extends ConsumerStatefulWidget {
  const BookShelf({super.key});

  @override
  ConsumerState<BookShelf> createState() => _BookShelfState();
}

class _BookShelfState extends ConsumerState<BookShelf> {
  @override
  void initState() {
    super.initState();
    if (!SpUtil.containsKey(PrefsKeys.topSafeHeight)) {
      SpUtil.putDouble(PrefsKeys.topSafeHeight, Screen.topSafeHeight);
    }
    if (!SpUtil.containsKey(PrefsKeys.shimmerNums)) {
      SpUtil.putInt(
        PrefsKeys.shimmerNums,
        (Screen.height -
                Screen.topSafeHeight -
                Screen.bottomSafeHeight -
                60) ~/
            25,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelfModel = ref.watch(shelfModelProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffold,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ShelfHeader(
                coverMode: shelfModel.cover,
                filter: shelfModel.filter,
                onFilter: shelfModel.setFilter,
                onSearch: () {
                  Routes.navigateTo(context, Routes.search, params: {
                    'type': 'book',
                    'name': '',
                  });
                },
                onToggleMode: shelfModel.toggleModel,
                onManage: () =>
                    Routes.navigateTo(context, Routes.sortShelf),
              ),
              Expanded(child: BooksWidget('')),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶栏：标题 + 数量 + 搜索 / 视图 / 整理
class _ShelfHeader extends StatelessWidget {
  final bool coverMode;
  final ShelfFilter filter;
  final ValueChanged<ShelfFilter> onFilter;
  final VoidCallback onSearch;
  final VoidCallback onToggleMode;
  final VoidCallback onManage;

  const _ShelfHeader({
    required this.coverMode,
    required this.filter,
    required this.onFilter,
    required this.onSearch,
    required this.onToggleMode,
    required this.onManage,
  });

  String _filterLabel(ShelfFilter value) {
    switch (value) {
      case ShelfFilter.all:
        return '全部';
      case ShelfFilter.reading:
        return '在读';
      case ShelfFilter.unread:
        return '未读';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;

    return Container(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: '书架',
            actions: [
              _HeaderIcon(
                icon: Icons.search,
                tooltip: '搜索',
                onTap: onSearch,
              ),
              _HeaderIcon(
                icon: coverMode
                    ? Icons.view_list_outlined
                    : Icons.grid_view_outlined,
                tooltip: coverMode ? '列表模式' : '封面模式',
                onTap: onToggleMode,
              ),
              _HeaderIcon(
                icon: Icons.checklist_rtl,
                tooltip: '书架整理',
                onTap: onManage,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: PaperSearchEntry(
              onTap: onSearch,
              hint: '搜索书架或全网书籍',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                for (final value in ShelfFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onFilter(value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filterLabel(value),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: filter == value
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: filter == value
                                  ? Theme.of(context).colorScheme.primary
                                  : (dark
                                      ? AppColors.textOnDark
                                      : AppColors.inkMute),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 16,
                            height: 2,
                            color: filter == value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ],
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
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 22,
        color: dark ? AppColors.textOnDark : AppColors.textPrimary,
      ),
    );
  }
}
