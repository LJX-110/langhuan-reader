import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';

/// One-line page header: title on the left, actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? AppColors.textOnDark : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontFamily: AppType.serif,
              fontSize: 22,
              height: 1.2,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Quiet inset search entry used by the shelf / discover pages.
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
