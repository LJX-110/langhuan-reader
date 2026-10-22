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
                    fontSize: 18,
                    height: 1.1,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppBrand.archiveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? AppColors.textOnDark : AppColors.inkMute,
                    fontSize: 8,
                    height: 1,
                    letterSpacing: 1.2,
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
    final muted = dark ? AppColors.textOnDark : AppColors.inkMute;
    final square = dark ? AppColors.textOnDark : AppColors.ink;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: muted,
              fontSize: 9,
              height: 1.2,
              letterSpacing: 1.8,
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
            width: 5,
            height: 5,
            color: square,
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
                    fontSize: 22,
                    height: 1.15,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: dark ? AppColors.textOnDark : AppColors.inkMute,
                      fontSize: 11,
                      height: 1.4,
                      letterSpacing: .3,
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
      color: surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: line, width: .5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 16,
                color: dark ? AppColors.textOnDark : AppColors.inkMute,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? AppColors.textOnDark : AppColors.inkMute,
                    fontSize: 12.5,
                    letterSpacing: .2,
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
