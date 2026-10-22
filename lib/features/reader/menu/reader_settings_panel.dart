import 'package:flutter/material.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/design/theme/color_model.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Settings level 1: font size, paper, page-turn mode and shortcuts.
class ReaderSettingsPanel extends StatelessWidget {
  const ReaderSettingsPanel({
    super.key,
    required this.readModel,
    required this.colorModel,
    required this.chrome,
    required this.onChanged,
    required this.onOpenLayout,
  });

  final ReadModel readModel;
  final ColorModel colorModel;
  final ReaderChrome chrome;
  final VoidCallback onChanged;
  final VoidCallback onOpenLayout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionLabel('字号', chrome),
          const SizedBox(height: 8),
          _stepperRow(
            chrome: chrome,
            label: '字号',
            valueText: ReadSetting.getFontSize().round().toString(),
            onMinus: () {
              ReadSetting.calcFontSize(-1);
              readModel.relayoutPages();
              onChanged();
            },
            onPlus: () {
              ReadSetting.calcFontSize(1);
              readModel.relayoutPages();
              onChanged();
            },
            child: _buildSlider(
              context: context,
              chrome: chrome,
              value: ReadSetting.getFontSize(),
              min: 10,
              max: 60,
              onChanged: (v) {
                ReadSetting.setFontSize(v);
                readModel.relayoutPages();
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel('背景', chrome),
          const SizedBox(height: 10),
          _paperSwatchRow(
            context: context,
            readModel: readModel,
            colorModel: colorModel,
            chrome: chrome,
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          _sectionLabel('翻页', chrome),
          const SizedBox(height: 10),
          _pageTurnModeRow(context, chrome, readModel, onChanged),
          const SizedBox(height: 16),
          _sectionLabel('更多', chrome),
          const SizedBox(height: 10),
          _settingTile(
            context: context,
            chrome: chrome,
            icon: Icons.format_line_spacing,
            title: '行距 · 段距 · 边距',
            onTap: onOpenLayout,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _settingTile(
                  context: context,
                  chrome: chrome,
                  icon: Icons.font_download_outlined,
                  title: '字体',
                  onTap: () => Routes.navigateTo(context, Routes.fontSet),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _settingTile(
                  context: context,
                  chrome: chrome,
                  icon: Icons.touch_app_outlined,
                  title: '单手模式',
                  trailing: SizedBox(
                    height: 24,
                    child: Switch.adaptive(
                      value: readModel.tapLeftToAdvance,
                      activeTrackColor: AppColors.accentOn(
                        context,
                        chrome.panelBg,
                      ),
                      onChanged: (_) {
                        readModel.toggleTapLeftToAdvance();
                        onChanged();
                      },
                    ),
                  ),
                  onTap: () {
                    readModel.toggleTapLeftToAdvance();
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings level 2: line height / paragraph spacing / side margin.
class ReaderLayoutPanel extends StatelessWidget {
  const ReaderLayoutPanel({
    super.key,
    required this.readModel,
    required this.chrome,
    required this.onChanged,
    required this.onBack,
  });

  final ReadModel readModel;
  final ReaderChrome chrome;
  final VoidCallback onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: chrome.fg,
                ),
                onPressed: onBack,
              ),
              Text(
                '排版',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: chrome.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _stepperRow(
            chrome: chrome,
            label: '行距',
            valueText: ReadSetting.getLineHeight().toStringAsFixed(1),
            onMinus: () {
              ReadSetting.subLineHeight();
              readModel.relayoutPages();
              onChanged();
            },
            onPlus: () {
              ReadSetting.addLineHeight();
              readModel.relayoutPages();
              onChanged();
            },
            child: _buildSlider(
              context: context,
              chrome: chrome,
              value: ReadSetting.getLineHeight(),
              min: 0.1,
              max: 4.0,
              onChanged: (v) {
                ReadSetting.setLineHeight(v);
                readModel.relayoutPages();
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 4),
          _stepperRow(
            chrome: chrome,
            label: '段距',
            valueText: ReadSetting.getParagraph().toStringAsFixed(1),
            onMinus: () {
              ReadSetting.subParagraph();
              readModel.relayoutPages();
              onChanged();
            },
            onPlus: () {
              ReadSetting.addParagraph();
              readModel.relayoutPages();
              onChanged();
            },
            child: _buildSlider(
              context: context,
              chrome: chrome,
              value: ReadSetting.getParagraph(),
              min: 0.1,
              max: 2.0,
              onChanged: (v) {
                ReadSetting.setParagraph(v);
                readModel.relayoutPages();
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 4),
          _stepperRow(
            chrome: chrome,
            label: '边距',
            valueText: '${ReadSetting.getPageDis()}',
            onMinus: () {
              ReadSetting.calcPageDis(-1);
              readModel.relayoutPages();
              onChanged();
            },
            onPlus: () {
              ReadSetting.calcPageDis(1);
              readModel.relayoutPages();
              onChanged();
            },
            child: _buildSlider(
              context: context,
              chrome: chrome,
              value: ReadSetting.getPageDis().toDouble(),
              min: 0,
              max: 50,
              onChanged: (v) {
                ReadSetting.setPageDis(v.toInt());
                readModel.relayoutPages();
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 10),
          _alignRow(context, chrome, readModel, onChanged),
        ],
      ),
    );
  }
}

Widget _alignRow(
  BuildContext context,
  ReaderChrome chrome,
  ReadModel readModel,
  VoidCallback onChanged,
) {
  final current = ReadSetting.getTextAlign();
  const options = <(String, String)>[('justify', '两端对齐'), ('left', '左对齐')];
  final accent = AppColors.accentOn(context, chrome.panelBg);
  final accentSoft = accent.withValues(alpha: .10);
  return Row(
    children: [
      SizedBox(
        width: 36,
        child: Text('对齐', style: TextStyle(fontSize: 13, color: chrome.fg)),
      ),
      for (final option in options)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: current == option.$1 ? accentSoft : chrome.chipBg,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (current == option.$1) return;
                  ReadSetting.setTextAlign(option.$1);
                  readModel.relayoutPages();
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Center(
                    child: Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: current == option.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: current == option.$1 ? accent : chrome.fg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

Widget _sectionLabel(String text, ReaderChrome chrome) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: chrome.muted,
      letterSpacing: 0.4,
    ),
  );
}

Widget _pageTurnModeRow(
  BuildContext context,
  ReaderChrome chrome,
  ReadModel readModel,
  VoidCallback onChanged,
) {
  const modes = <(int, String, IconData)>[
    (0, '无动画', Icons.flash_on_outlined),
    (2, '覆盖', Icons.layers_outlined),
    (1, '仿真', Icons.auto_stories_outlined),
    (3, '滚动', Icons.swap_vert),
  ];
  final current = readModel.currentAnimationMode;
  final accent = AppColors.accentOn(context, chrome.panelBg);
  final accentSoft = accent.withValues(alpha: .10);
  return Row(
    children: modes.map((m) {
      final selected = current == m.$1;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: selected ? accentSoft : chrome.chipBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                readModel.setAnimationMode(m.$1);
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Icon(m.$3, size: 18, color: selected ? accent : chrome.fg),
                    const SizedBox(height: 4),
                    Text(
                      m.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? accent : chrome.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

/// Label | − | slider | + | value
Widget _stepperRow({
  required ReaderChrome chrome,
  required String label,
  required String valueText,
  required VoidCallback onMinus,
  required VoidCallback onPlus,
  required Widget child,
}) {
  return Row(
    children: [
      SizedBox(
        width: 36,
        child: Text(label, style: TextStyle(fontSize: 13, color: chrome.fg)),
      ),
      _roundIconBtn(chrome, Icons.remove, onMinus),
      Expanded(child: child),
      _roundIconBtn(chrome, Icons.add, onPlus),
      SizedBox(
        width: 32,
        child: Text(
          valueText,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            color: chrome.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}

Widget _roundIconBtn(ReaderChrome chrome, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: chrome.chipBg, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: chrome.fg),
    ),
  );
}

Widget _buildSlider({
  required BuildContext context,
  required ReaderChrome chrome,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
}) {
  return SliderTheme(
    data: readerSliderTheme(context, chrome),
    child: Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      onChanged: onChanged,
    ),
  );
}

Widget _paperSwatchRow({
  required BuildContext context,
  required ReadModel readModel,
  required ColorModel colorModel,
  required ReaderChrome chrome,
  required VoidCallback onChanged,
}) {
  final current = ReadSetting.getPaperTheme();
  final accent = AppColors.accentOn(context, chrome.panelBg);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: ReadSetting.solidPapers.map((t) {
      final selected = current == t;
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final wasDark = colorModel.dark;
            await readModel.setPaperTheme(t);
            final nowDark = t == PaperTheme.night;
            if (wasDark != nowDark) {
              colorModel.switchModel();
            }
            onChanged();
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ReadSetting.paperColor(t),
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: selected ? 2.5 : 1,
                    color: selected ? accent : chrome.divider,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: t == PaperTheme.night ? Colors.white70 : accent,
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                ReadSetting.paperLabel(t),
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? accent : chrome.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

Widget _settingTile({
  required BuildContext context,
  required ReaderChrome chrome,
  required IconData icon,
  required String title,
  Widget? trailing,
  required VoidCallback onTap,
}) {
  return Material(
    color: chrome.chipBg,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: chrome.fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 13, color: chrome.fg),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, size: 18, color: chrome.muted),
          ],
        ),
      ),
    ),
  );
}
