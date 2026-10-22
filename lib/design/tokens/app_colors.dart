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
  static const Color lineSoft = Color(0xFFF2F2F2);

  // Accent aliases.
  static const Color qingmo = teal;
  static const Color qingmoSoft = Color(0xFF6FA8AE);
  static const Color seal = gold;

  // Backward-compatible semantic names used across the existing UI.
  static const Color brand = qingmo;
  static const Color brandPressed = teal;
  static const Color brandSoft = Color(0x141B5C66);

  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color accentSoftOf(BuildContext context, {double alpha = 0.10}) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: alpha);

  static const Color scaffold = paper;
  static const Color surface = paperLight;
  static const Color divider = line;
  static const Color cardBorder = lineSoft;

  static const Color textPrimary = ink;
  static const Color textSecondary = inkSoft;
  static const Color textTertiary = inkMute;
  static const Color textOnBrand = white;
  static const Color textOnDark = Color(0xFFF5F5F5);

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
  static const double searchBarHeight = 38;
  static const double ctaHeight = 44;
  static const double coverAspect = 0.72; // width / height
  static const int shelfColumns = 3;
  static const double shelfSpacing = 14;
  static const double shelfRunSpacing = 18;
  static const double dockHeight = 62;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> cover = [
    BoxShadow(
      color: Color(0x1F1F1E1B),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> softBar = [
    BoxShadow(
      color: Color(0x0D1F1E1B),
      blurRadius: 10,
      offset: Offset(0, -2),
    ),
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
}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final background = dark ? AppColors.scaffoldDark : AppColors.scaffold;
  final surface = dark ? AppColors.surfaceDark : AppColors.surface;
  final onSurface = dark ? AppColors.textOnDark : AppColors.textPrimary;
  final primary = dark ? AppColors.qingmoSoft : AppColors.qingmo;
  final line = dark ? AppColors.dividerDark : AppColors.line;
  final secondary = dark ? const Color(0xFFB3B3B3) : AppColors.inkSoft;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: dark ? AppColors.ink : AppColors.paperLight,
    secondary: AppColors.gold,
    onSecondary: AppColors.black,
    error: AppColors.cinnabar,
    onError: AppColors.white,
    surface: surface,
    onSurface: onSurface,
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
    titleMedium: TextStyle(
      color: onSurface,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(color: onSurface, height: 1.5),
    bodyMedium: TextStyle(color: onSurface, height: 1.5),
    bodySmall: TextStyle(color: secondary, height: 1.5),
    labelLarge: TextStyle(
      color: onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    ),
    labelSmall: TextStyle(
      color: secondary,
      letterSpacing: 1.2,
    ),
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
      selectedItemColor: primary,
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
      backgroundColor: primary,
      foregroundColor: AppColors.paperLight,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.paperLight,
        elevation: 0,
        minimumSize: const Size(0, AppDimens.ctaHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      thumbColor: primary,
      inactiveTrackColor: primary.withValues(alpha: 0.18),
      overlayColor: primary.withValues(alpha: 0.10),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return primary;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.42);
        }
        return null;
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? AppColors.surfaceDark : AppColors.paper,
      selectedColor: primary.withValues(alpha: 0.10),
      checkmarkColor: primary,
      labelStyle: TextStyle(
        color: onSurface,
        fontSize: 12,
        fontFamily: fontFamily,
      ),
      secondaryLabelStyle: TextStyle(
        color: primary,
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
        borderSide: BorderSide(color: primary, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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

/// Kept for older call sites while the design system settles.
ThemeData buildWeReadTheme({
  required bool dark,
  String? fontFamily,
  Color? accent,
}) =>
    buildLanghuanTheme(dark: dark, fontFamily: fontFamily);
