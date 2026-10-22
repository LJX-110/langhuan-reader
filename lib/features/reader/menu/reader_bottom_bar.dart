import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';

/// Four fixed tabs under the reader bottom panel.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.chrome,
    required this.night,
    required this.downloadActive,
    required this.settingsActive,
    required this.onChapters,
    required this.onToggleNight,
    required this.onDownload,
    required this.onSettings,
  });

  final ReaderChrome chrome;
  final bool night;
  final bool downloadActive;
  final bool settingsActive;
  final VoidCallback onChapters;
  final VoidCallback onToggleNight;
  final VoidCallback onDownload;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: <Widget>[
          _bottomTab(
            context: context,
            label: '目录',
            icon: Icons.menu,
            active: false,
            onTap: onChapters,
          ),
          _bottomTab(
            context: context,
            label: night ? '日间' : '夜间',
            icon: night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            active: false,
            onTap: onToggleNight,
          ),
          _bottomTab(
            context: context,
            label: '缓存',
            icon: Icons.cloud_download_outlined,
            active: downloadActive,
            onTap: onDownload,
          ),
          _bottomTab(
            context: context,
            label: '设置',
            icon: Icons.tune,
            active: settingsActive,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }

  Widget _bottomTab({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? AppColors.accentOf(context) : chrome.fg;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
