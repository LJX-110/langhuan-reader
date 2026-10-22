import 'package:flutter/material.dart';

/// One selectable two-colour theme.
///
/// [accent] drives buttons, selected states and icons. [secondary] is a small
/// companion colour for spines, chips and secondary marks; the page itself
/// stays white (light) or near-black (dark) so bright neon colours never
/// become a full-page background.
class LanghuanThemePreset {
  const LanghuanThemePreset(this.name, this.accent, this.secondary);

  final String name;
  final Color accent;
  final Color secondary;
}

class LanghuanThemes {
  LanghuanThemes._();

  static const int defaultIndex = 1;

  static const List<LanghuanThemePreset> all = [
    LanghuanThemePreset('橘橙 · 青金石', Color(0xFFFD742D), Color(0xFF01008A)),
    LanghuanThemePreset('鸢尾蓝 · 流光白', Color(0xFF0F64B5), Color(0xFFFFFBEA)),
    LanghuanThemePreset('荧光绿 · 深空灰', Color(0xFF08FC2E), Color(0xFF101820)),
    LanghuanThemePreset('火山橙 · 藏蓝', Color(0xFFFF6047), Color(0xFF000035)),
    LanghuanThemePreset('电光蓝 · 玫红', Color(0xFF12F2FD), Color(0xFFE4058E)),
    LanghuanThemePreset('金菊 · 晶石紫', Color(0xFFFADE1F), Color(0xFF690DAD)),
    LanghuanThemePreset('靓丽黄 · 宝蓝', Color(0xFFFFFF00), Color(0xFF002FA7)),
    LanghuanThemePreset('瓦松绿 · 玉子', Color(0xFF4E8966), Color(0xFFFFFEEE)),
    LanghuanThemePreset('米白 · 凝液紫', Color(0xFFFFFBEA), Color(0xFF47176D)),
    LanghuanThemePreset('电光蓝 · 晶石紫', Color(0xFF00F0FD), Color(0xFF690DAD)),
    LanghuanThemePreset('旭日黄 · 深灰绿', Color(0xFFFDEB55), Color(0xFF185A56)),
    LanghuanThemePreset('勃艮第红 · 米白', Color(0xFF470125), Color(0xFFFFFBEA)),
  ];
}
