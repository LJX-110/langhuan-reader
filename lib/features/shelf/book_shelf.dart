import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/design/components/archive_header.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
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
    final count = shelfModel.shelf.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffold,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ShelfHeader(
                count: count,
                coverMode: shelfModel.cover,
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
  final int count;
  final bool coverMode;
  final VoidCallback onSearch;
  final VoidCallback onToggleMode;
  final VoidCallback onManage;

  const _ShelfHeader({
    required this.count,
    required this.coverMode,
    required this.onSearch,
    required this.onToggleMode,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;

    return Container(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchiveBrandBar(
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
          const ArchiveLabel('01 / 藏书'),
          ArchiveTitle(
            title: '书架',
            subtitle: count == 0 ? '暂无藏书' : '共 $count 本 · 私人书阁',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: PaperSearchEntry(
              onTap: onSearch,
              hint: '搜索书架或全网书籍',
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
