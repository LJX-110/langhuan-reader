import 'package:langhuan/app/providers.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/design/brand/app_brand.dart';
import 'package:langhuan/design/components/archive_header.dart';
import 'package:langhuan/design/components/seal_mark.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/profile/info_page.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:langhuan/features/settings/skin_page.dart';
import 'package:langhuan/features/sources/source_repo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 我的：私人书阁的入口，不是账号中心。
class Me extends ConsumerWidget {
  final bool embedded;

  const Me({this.embedded = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;
    final shelfCount = ref.watch(shelfModelProvider).shelf.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ArchiveBrandBar(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: embedded ? 18 : 32,
                  ),
                  children: [
                    const ArchiveLabel('01 / 书阁'),
                    const ArchiveTitle(
                      title: '我的',
                      subtitle: '私人书阁 · 本机 · 无账号',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _profileCard(context, shelfCount),
                    ),
                    _sectionLabel('阅读与整理'),
                    _sectionCard(context, [
                      _tile(
                        context: context,
                        icon: Icons.text_fields_outlined,
                        title: '字体设置',
                        subtitle: '阅读字体、字号与本地导入',
                        onTap: () =>
                            Routes.navigateTo(context, Routes.fontSet),
                      ),
                      _tile(
                        context: context,
                        icon: Icons.inventory_2_outlined,
                        title: '缓存管理',
                        subtitle: '章节正文、分页缓存与占用',
                        onTap: () =>
                            Routes.navigateTo(context, Routes.cache),
                      ),
                      _tile(
                        context: context,
                        icon: Icons.palette_outlined,
                        title: '主题',
                        subtitle: '明暗模式与纸色',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const Skin()),
                          );
                        },
                        showDivider: false,
                      ),
                    ]),
                    _sectionLabel('书源'),
                    _sectionCard(context, [
                      _tile(
                        context: context,
                        icon: Icons.library_books_outlined,
                        title: '书源管理',
                        subtitle: '导入、启用与整理自己的书源',
                        onTap: () =>
                            Routes.navigateTo(context, Routes.sources),
                      ),
                      _tile(
                        context: context,
                        icon: Icons.cloud_download_outlined,
                        title: '私有书源仓库',
                        subtitle: '手动同步自己的 JSON 地址',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SourceRepoPage(),
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ]),
                    _sectionLabel('其他'),
                    _sectionCard(context, [
                      _tile(
                        context: context,
                        icon: Icons.campaign_outlined,
                        title: '公告',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const InfoPage()),
                          );
                        },
                      ),
                      _tile(
                        context: context,
                        icon: Icons.gavel_outlined,
                        title: '免责声明',
                        onTap: () => _showLaw(context),
                      ),
                      _tile(
                        context: context,
                        icon: Icons.article_outlined,
                        title: '运行日志',
                        onTap: () => Routes.navigateTo(context, Routes.logs),
                      ),
                      _tile(
                        context: context,
                        icon: Icons.info_outline,
                        title: '关于',
                        onTap: () => _showAbout(context),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'v${SpUtil.getString(PrefsKeys.version, defValue: '')}',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: AppColors.inkMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(BuildContext context, int shelfCount) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: line.withValues(alpha: .8), width: .5),
      ),
      child: Row(
        children: [
          const SealMark(size: 48, text: '琅'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '私人书阁',
                  style: TextStyle(
                    fontFamily: AppType.serif,
                    fontSize: 20,
                    height: 1.2,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppBrand.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkMute,
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$shelfCount',
                style: const TextStyle(
                  fontFamily: AppType.serif,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '藏书',
                style: TextStyle(
                  color: AppColors.inkMute,
                  fontSize: 8,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 7),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.inkMute,
          fontSize: 9,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: line.withValues(alpha: .85), width: .5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final iconBg = dark
        ? AppColors.qingmoSoft.withValues(alpha: .12)
        : AppColors.qingmo.withValues(alpha: .07);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primary,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkMute,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.inkMute,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 55,
            color: line.withValues(alpha: .8),
          ),
      ],
    );
  }

  void _showLaw(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('免责声明'),
        content: SingleChildScrollView(
          child: Text(ReadSetting.lawWarn),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppBrand.name} V${SpUtil.getString(PrefsKeys.version)}'),
        content: Text(
          ReadSetting.poet,
          style: const TextStyle(fontSize: 15, height: 2.1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
