import 'package:flutter/material.dart';

import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';

/// In-chapter keyword search, shown in place of the reader top bar.
class ReaderFindBar extends StatelessWidget {
  const ReaderFindBar({
    super.key,
    required this.chrome,
    required this.controller,
    required this.index,
    required this.total,
    required this.snippet,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final ReaderChrome chrome;
  final TextEditingController controller;
  final int index;
  final int total;
  final String snippet;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.paperLight;
    final line = chrome.divider;
    final label = total == 0 ? '无结果' : '${index + 1}/$total';

    return Container(
      decoration: BoxDecoration(
        color: chrome.panelBg,
        boxShadow: AppShadows.softBar,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '关闭查找',
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: chrome.fg,
                    ),
                    onPressed: onClose,
                  ),
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: dark ? 1 : .6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: line, width: .5),
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: onChanged,
                        style: TextStyle(fontSize: 14, color: chrome.fg),
                        cursorColor: AppColors.accentOf(context),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '在本章查找',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: chrome.muted,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: chrome.muted,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: chrome.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '上一处',
                    icon: Icon(
                      Icons.keyboard_arrow_up,
                      size: 22,
                      color: chrome.fg,
                    ),
                    onPressed: total == 0 ? null : onPrev,
                  ),
                  IconButton(
                    tooltip: '下一处',
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: chrome.fg,
                    ),
                    onPressed: total == 0 ? null : onNext,
                  ),
                ],
              ),
              if (snippet.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 2, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      snippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: chrome.muted),
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
