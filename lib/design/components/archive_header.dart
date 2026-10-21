import 'package:flutter/material.dart';

import 'package:langhuan/design/brand/app_brand.dart';
import 'package:langhuan/design/components/seal_mark.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// Brand strip used by the three main pages.
class ArchiveBrandBar extends StatelessWidget {
  const ArchiveBrandBar({
    super.key,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 6, 8, 6),
  });

  final List<Widget> actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const SealMark(size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppBrand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontFamily: AppType.serif,
                    fontSize: 19,
                    height: 1.1,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppBrand.archiveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkMute,
                    fontSize: 8,
                    height: 1,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Section eyebrow: a hairline, a label, and a tiny cinnabar block.
class ArchiveLabel extends StatelessWidget {
  const ArchiveLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 1,
            color: AppColors.seal,
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.inkMute,
              fontSize: 9,
              height: 1.2,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Container(height: .5, color: line)),
          const SizedBox(width: 9),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 7),
          ],
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.seal,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveTitle extends StatelessWidget {
  const ArchiveTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primary,
                    fontFamily: AppType.serif,
                    fontSize: 28,
                    height: 1.15,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.inkMute,
                      fontSize: 11,
                      height: 1.4,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// A paper search entry styled as a quiet inset field.
class PaperSearchEntry extends StatelessWidget {
  const PaperSearchEntry({
    super.key,
    required this.onTap,
    this.hint = '搜索书名 / 作者',
  });

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    return Material(
      color: surface.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: AppDimens.searchBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line.withValues(alpha: .9), width: .5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 17,
                color: AppColors.inkMute,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkMute,
                    fontSize: 12.5,
                    letterSpacing: .3,
                  ),
                ),
              ),
              const Text(
                '全域',
                style: TextStyle(
                  color: AppColors.inkMute,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
