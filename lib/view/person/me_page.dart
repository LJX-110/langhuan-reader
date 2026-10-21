import 'package:langhuan/common/app_brand.dart';
import 'package:langhuan/common/read_setting.dart';
import 'package:langhuan/common/app_colors.dart';
import 'package:langhuan/common/local_store.dart';
import 'package:langhuan/route/routes.dart';
import 'package:langhuan/view/person/info_page.dart';
import 'package:langhuan/view/person/skin_page.dart';
import 'package:langhuan/view/person/source_repo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langhuan/common/common.dart';

/// 「我的」页（微信读书风格）
class Me extends ConsumerWidget {
  /// Hosted inside MainShell bottom tab.
  final bool embedded;

  const Me({this.embedded = false, super.key});

  bool get _dark => SpUtil.getBool(PrefsKeys.dark);

  Color get _scaffold => _dark ? AppColors.scaffoldDark : AppColors.scaffold;
  Color get _surface => _dark ? AppColors.surfaceDark : AppColors.surface;
  Color get _primary => _dark ? AppColors.textOnDark : AppColors.textPrimary;
  Color get _secondary => AppColors.textSecondary;
  Color get _divider => _dark ? AppColors.dividerDark : AppColors.divider;
  Color get _iconBg =>
      _dark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = embedded
        ? MediaQuery.of(context).padding.top + 8
        : MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _scaffold,
        body: Column(
          children: [
            SizedBox(height: topPad),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _profileCard(context),
                  const SizedBox(height: 16),
                  _sectionCard([
                    _tile(
                      context: context,
                      icon: Icons.campaign_outlined,
                      title: '公告',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => InfoPage()),
                        );
                      },
                    ),
                    _tile(
                      context: context,
                      icon: Icons.gavel_outlined,
                      title: '免责声明',
                      onTap: () => _showLaw(context),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _sectionCard([
                    _tile(
                      context: context,
                      icon: Icons.library_books_outlined,
                      title: '书源管理',
                      onTap: () =>
                          Routes.navigateTo(context, Routes.sources),
                    ),
                    _tile(
                      context: context,
                      icon: Icons.cloud_download_outlined,
                      title: '私有书源仓库',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SourceRepoPage(),
                          ),
                        );
                      },
                    ),
                    _tile(
                      context: context,
                      icon: Icons.palette_outlined,
                      title: '主题',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => Skin()),
                        );
                      },
                    ),
                    _tile(
                      context: context,
                      icon: Icons.article_outlined,
                      title: '运行日志',
                      onTap: () => Routes.navigateTo(context, Routes.logs),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _sectionCard([
                    _tile(
                      context: context,
                      icon: Icons.info_outline,
                      title: '关于',
                      onTap: () => _showAbout(context),
                      showDivider: false,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'v${SpUtil.getString(PrefsKeys.version, defValue: "")}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
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

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Widget _profileCard(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _iconBg,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 26,
                color: AppColors.accentOf(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppBrand.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppBrand.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondary,
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

  // ---------------------------------------------------------------------------
  // Section / tile
  // ---------------------------------------------------------------------------

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
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
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _primary,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: _secondary),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 60,
            color: _divider,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

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
