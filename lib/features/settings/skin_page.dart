import 'package:langhuan/app/providers.dart';
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
          final divider = Theme.of(context).dividerColor;
          final accent = Theme.of(context).colorScheme.primary;
          return Scaffold(
            appBar: AppBar(
              title: const Text('主题'),
              centerTitle: false,
            ),
            body: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                return InkWell(
                  onTap: () => data.selectTheme(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
                    child: Row(
                      children: [
                        _swatch(preset.accent, divider),
                        const SizedBox(width: 6),
                        _swatch(preset.secondary, divider),
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
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _swatch(Color color, Color border) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border, width: .5),
      ),
    );
  }
}
