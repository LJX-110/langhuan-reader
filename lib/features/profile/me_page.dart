import 'package:langhuan/app/providers.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/design/brand/app_brand.dart';
import 'package:langhuan/design/components/page_header.dart';
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
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final muted = dark ? AppColors.textOnDark : AppColors.inkMute;
    final count = ref.watch(shelfModelProvider).shelf.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PageHeader(title: '我的'),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(bottom: embedded ? 18 : 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      child: Row(
                        children: [
                          Text(
                            '私人书阁',
                            style: TextStyle(
                              color: dark
                                  ? AppColors.textOnDark
                                  : AppColors.ink,
                              fontFamily: AppType.serif,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$count 本',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _section(context, '阅读与整理', [
                      _row(
                        context,
                        '字体设置',
                        () => Routes.navigateTo(context, Routes.fontSet),
                        line: line,
                      ),
                      _row(
                        context,
                        '缓存管理',
                        () => Routes.navigateTo(context, Routes.cache),
                        line: line,
                      ),
                      _row(
                        context,
                        '主题',
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const Skin()),
                        ),
                        line: line,
                        last: true,
                      ),
                    ]),
                    _section(context, '书源', [
                      _row(
                        context,
                        '书源管理',
                        () => Routes.navigateTo(context, Routes.sources),
                        line: line,
                      ),
                      _row(
                        context,
                        '私有书源仓库',
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SourceRepoPage(),
                          ),
                        ),
                        line: line,
                        last: true,
                      ),
                    ]),
                    _section(context, '其他', [
                      _row(
                        context,
                        '公告',
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InfoPage()),
                        ),
                        line: line,
                      ),
                      _row(
                        context,
                        '免责声明',
                        () => _showLaw(context),
                        line: line,
                      ),
                      _row(
                        context,
                        '运行日志',
                        () => Routes.navigateTo(context, Routes.logs),
                        line: line,
                      ),
                      _row(
                        context,
                        '关于',
                        () => _showAbout(context),
                        line: line,
                        last: true,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'v${SpUtil.getString(PrefsKeys.version, defValue: '')}',
                        style: TextStyle(fontSize: 10, color: muted),
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

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...rows,
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    VoidCallback onTap, {
    required Color line,
    bool last = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textOnDark : AppColors.inkMute;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        color: primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: muted),
                ],
              ),
            ),
          ),
        ),
        if (!last) Divider(height: .5, color: line),
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
