import 'package:langhuan/app/providers.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/design/theme/theme_presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Skin extends ConsumerWidget {
  const Skin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(colorModelProvider);
    return Theme(
      data: data.theme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final divider = theme.dividerColor;
          final accent = AppColors.accentOf(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(
                '主题',
                style: TextStyle(color: AppColors.accentLargeOf(context)),
              ),
              centerTitle: false,
            ),
            body: Column(
              children: [
                _ThemePreview(divider: divider),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: 8 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: LanghuanThemes.all.length,
                    separatorBuilder: (_, _) => Divider(
                      height: .5,
                      indent: 20,
                      endIndent: 20,
                      color: divider,
                    ),
                    itemBuilder: (context, i) {
                      final preset = LanghuanThemes.all[i];
                      final selected = data.themeIndex == i;
                      return Material(
                        color: selected
                            ? accent.withValues(alpha: .06)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => data.selectTheme(i),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: Row(
                              children: [
                                _swatchPair(
                                  preset.accent,
                                  preset.secondary,
                                  divider,
                                  index: i,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check, size: 18, color: accent),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _swatchPair(
    Color accent,
    Color secondary,
    Color border, {
    required int index,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: border, width: .5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                key: ValueKey('theme-swatch-$index-accent'),
                color: accent,
              ),
            ),
            Expanded(
              child: ColoredBox(
                key: ValueKey('theme-swatch-$index-secondary'),
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows how the current theme lands on a page: title, mark, fill and chip.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.divider});

  final Color divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AppColors.accentLargeOf(context);
    final accent = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);
    final primary = AppColors.themeAccentOf(context);
    final onPrimary = AppColors.onColorOf(primary);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border.all(color: divider, width: .5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前主题',
            style: TextStyle(fontSize: 11, color: muted, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '书房',
                style: TextStyle(
                  color: label,
                  fontFamily: AppType.serif,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(width: 40, height: 3, color: companion),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '开始阅读',
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '在读',
                  style: TextStyle(color: accent, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
