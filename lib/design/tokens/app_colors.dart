import 'package:flutter/material.dart';

/// 琅嬛阁 design tokens.
///
/// Chrome should read these through [ThemeData] where possible. The reader
/// canvas keeps using explicit paper tokens through `ReadSetting` so a skin
/// change never recolours the text being read.
class AppColors {
  AppColors._();

  // Five-colour system: white, black, teal, gold, cinnabar.
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF141414);
  static const Color teal = Color(0xFF1B5C66);
  static const Color gold = Color(0xFFC9A24B);
  static const Color cinnabar = Color(0xFFA8483A);

  // Neutral surfaces and type, derived from black / white.
  static const Color paper = white;
  static const Color paperLight = white;
  static const Color paperDeep = Color(0xFFF2F2F2);
  static const Color ink = black;
  static const Color inkSoft = Color(0xFF4D4D4D);
  static const Color inkMute = Color(0xFF6E6E6E);
  static const Color line = Color(0xFFE8E8E8);

  // Accent aliases.
  static const Color qingmo = teal;
  static const Color qingmoSoft = Color(0xFF6FA8AE);

  /// Accent for text and icons: keeps the hue of the chosen theme colour but
  /// darkens or lightens it until it reads on the page background. Fills use
  /// the visible theme colour in [ColorScheme.primary]; a near-page swatch
  /// falls back to the companion instead of disappearing.
  static Color accentOf(BuildContext context) {
    final theme = Theme.of(context);
    return readableAccent(themeAccentOf(context), theme.brightness);
  }

  /// Accent for large text (22px page titles). Large text only needs 3:1, so
  /// vivid colours stay closer to the chosen swatch than [accentOf].
  static Color accentLargeOf(BuildContext context) {
    final theme = Theme.of(context);
    return readableAccent(
      themeAccentOf(context),
      theme.brightness,
      minRatio: 3,
    );
  }

  static Color accentSoftOf(BuildContext context, {double alpha = 0.10}) =>
      accentOf(context).withValues(alpha: alpha);

  /// The theme colour that can lead on the page. A near-white primary
  /// (e.g. 米白 · 凝液紫) cannot lead on a white page, so the companion
  /// becomes the identity colour instead of turning muddy.
  static Color themeAccentOf(BuildContext context) {
    final theme = Theme.of(context);
    return themeAccentFor(
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.brightness,
    );
  }

  static Color themeAccentFor(
    Color primary,
    Color secondary,
    Brightness background,
  ) {
    final page = background == Brightness.dark ? scaffoldDark : scaffold;
    final pageLightness = HSLColor.fromColor(page).lightness;
    final primaryLightness = HSLColor.fromColor(primary).lightness;
    final nearPage =
        contrastRatio(primary, page) < 1.6 &&
        (primaryLightness - pageLightness).abs() < .18;
    if (!nearPage) return primary;

    final secondaryLightness = HSLColor.fromColor(secondary).lightness;
    final secondaryNearPage =
        contrastRatio(secondary, page) < 1.6 &&
        (secondaryLightness - pageLightness).abs() < .18;
    if (!secondaryNearPage) return secondary;

    return readableAccent(primary, background);
  }

  /// Companion colour for small marks (dock underline, filter rules). Raw
  /// colour when it is visible; a near-white companion falls back to the
  /// visible accent instead of darkening into an unrelated olive tone.
  static Color companionOf(BuildContext context) {
    final theme = Theme.of(context);
    return companionFor(
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.brightness,
    );
  }

  static Color companionFor(
    Color primary,
    Color secondary,
    Brightness background,
  ) {
    final page = background == Brightness.dark ? scaffoldDark : scaffold;
    if (contrastRatio(secondary, page) >= 1.6) return secondary;
    return readableAccent(
      themeAccentFor(primary, secondary, background),
      background,
    );
  }

  /// Accent readable on an explicit background such as reader paper.
  static Color accentOn(BuildContext context, Color background) =>
      readableAccent(
        themeAccentOf(context),
        ThemeData.estimateBrightnessForColor(background),
      );

  /// Pick whichever of black / white actually reads better on [color].
  ///
  /// `ThemeData.estimateBrightnessForColor` flips near luminance 0.337; a
  /// colour just below that (e.g. #FD742D) got white text at ~2.7:1. Comparing
  /// both contrast ratios keeps every fill at its best available contrast.
  static Color onColorOf(Color color) {
    // Pure black / white, not the softer text tokens: a fill only needs to
    // maximize contrast, and #141414 fell just under 4.5:1 on 瓦松绿.
    const pureWhite = Color(0xFFFFFFFF);
    const pureBlack = Color(0xFF000000);
    return contrastRatio(color, pureWhite) >= contrastRatio(color, pureBlack)
        ? pureWhite
        : pureBlack;
  }

  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + .05) / (lo + .05);
  }

  /// Move lightness away from the page until [minRatio] is reached.
  /// Hue and saturation stay put, so a gold theme still looks gold instead of
  /// turning into grey.
  static Color readableAccent(
    Color color,
    Brightness background, {
    double minRatio = 4.5,
  }) {
    final target = background == Brightness.dark ? black : white;
    final hsl = HSLColor.fromColor(color);
    var lightness = hsl.lightness;
    var out = color;
    final step = background == Brightness.dark ? .05 : -.05;
    for (var i = 0; i < 20; i++) {
      if (contrastRatio(out, target) >= minRatio) return out;
      final next = (lightness + step).clamp(0.0, 1.0);
      if (next == lightness) break;
      lightness = next;
      out = hsl.withLightness(lightness).toColor();
    }
    return out;
  }

  static const Color scaffold = paper;
  static const Color surface = paperLight;
  static const Color divider = line;

  static const Color textPrimary = ink;
  static const Color textSecondary = inkSoft;
  static const Color textTertiary = inkMute;
  static const Color textOnDark = Color(0xFFF5F5F5);
  static const Color textMutedDark = Color(0xFFB3B3B3);

  static const Color danger = cinnabar;
  static const Color updateBadge = cinnabar;

  // Reader paper (product defaults). Values stay in AppColors so the reader
  // and chrome cannot drift apart.
  static const Color paperWhite = Color(0xFFFAF8F2);
  static const Color paperCream = Color(0xFFF3F1EA);
  static const Color paperGreen = Color(0xFFDDE7E0);
  static const Color paperNight = Color(0xFF111512);

  static const Color inkOnLight = ink;
  static const Color inkOnGreen = Color(0xFF243A30);
  static const Color inkOnNight = Color(0xFFB9B2A5);

  // Dark chrome
  static const Color scaffoldDark = Color(0xFF0E0E0E);
  static const Color surfaceDark = Color(0xFF181818);
  static const Color dividerDark = Color(0xFF2A2A2A);
}

class AppDimens {
  AppDimens._();

  static const double pagePadding = 16;
  static const double coverRadius = 5;
  static const double cardRadius = 12;
  static const double ctaHeight = 44;
  static const double coverAspect = 0.72; // width / height
  static const double shelfSpacing = 14;
  static const double shelfRunSpacing = 18;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> cover = [
    BoxShadow(color: Color(0x1F1F1E1B), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> softBar = [
    BoxShadow(color: Color(0x0D1F1E1B), blurRadius: 10, offset: Offset(0, -2)),
  ];
}

class AppType {
  AppType._();

  static const String serif = 'serif';
  static const String sans = 'HarmonyOSSansSC';
}

ThemeData buildLanghuanTheme({
  required bool dark,
  String? fontFamily,
  Color? accent,
  Color? secondaryColor,
}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final background = dark ? AppColors.scaffoldDark : AppColors.scaffold;
  final surface = dark ? AppColors.surfaceDark : AppColors.surface;
  final onSurface = dark ? AppColors.textOnDark : AppColors.textPrimary;
  final primary = accent ?? (dark ? AppColors.qingmoSoft : AppColors.qingmo);
  final secondary = secondaryColor ?? AppColors.gold;
  final fill = AppColors.themeAccentFor(primary, secondary, brightness);
  final onFill = AppColors.onColorOf(fill);
  final accentInk = AppColors.readableAccent(fill, brightness);
  final companionInk = AppColors.readableAccent(
    AppColors.companionFor(primary, secondary, brightness),
    brightness,
  );
  final line = dark ? AppColors.dividerDark : AppColors.line;
  final muted = dark ? AppColors.textMutedDark : AppColors.inkSoft;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: fill,
    onPrimary: onFill,
    secondary: secondary,
    onSecondary: AppColors.onColorOf(secondary),
    error: AppColors.cinnabar,
    onError: AppColors.white,
    surface: surface,
    onSurface: onSurface,
    outline: line,
    onSurfaceVariant: muted,
  );

  final baseText = TextTheme(
    displayLarge: TextStyle(
      fontFamily: AppType.serif,
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: 2,
    ),
    displayMedium: TextStyle(
      fontFamily: AppType.serif,
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: AppType.serif,
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    ),
    titleLarge: TextStyle(
      fontFamily: AppType.serif,
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: .8,
    ),
    titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: onSurface, height: 1.5),
    bodyMedium: TextStyle(color: onSurface, height: 1.5),
    bodySmall: TextStyle(color: companionInk, height: 1.5),
    labelLarge: TextStyle(
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    ),
    labelSmall: TextStyle(color: companionInk, letterSpacing: 1.2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    fontFamily: fontFamily,
    textTheme: baseText.apply(
      fontFamily: fontFamily,
      bodyColor: onSurface,
      displayColor: onSurface,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: background,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: onSurface),
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: AppType.serif,
        letterSpacing: 1,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accentInk,
      unselectedItemColor: AppColors.inkMute,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, thickness: .5, space: 1),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(color: line.withValues(alpha: .75), width: .5),
      ),
    ),
    iconTheme: IconThemeData(color: onSurface),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: fill,
      foregroundColor: onFill,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentInk),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: onFill,
        elevation: 0,
        minimumSize: const Size(0, AppDimens.ctaHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: fill,
      thumbColor: fill,
      inactiveTrackColor: fill.withValues(alpha: 0.18),
      overlayColor: fill.withValues(alpha: 0.10),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return fill;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) {
          return fill.withValues(alpha: 0.42);
        }
        return null;
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? AppColors.surfaceDark : AppColors.paper,
      selectedColor: fill.withValues(alpha: 0.10),
      checkmarkColor: accentInk,
      labelStyle: TextStyle(
        color: onSurface,
        fontSize: 12,
        fontFamily: fontFamily,
      ),
      secondaryLabelStyle: TextStyle(
        color: accentInk,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: line, width: .5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: AppColors.inkMute, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: line, width: .5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: fill, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: AppType.serif,
        letterSpacing: 1,
      ),
    ),
  );
}
