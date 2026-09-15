import 'package:flutter/material.dart';

/// Design tokens from the Voylog design handoff
/// (`Voylog UI/design_handoff_voylog/README.md`) -- soft sky-blue palette,
/// pill-shaped controls, blue-tinted shadows instead of grey. Values here
/// are copied verbatim from the handoff's Design Tokens table so screens
/// stay pixel-faithful to the reference.
class AppColors {
  AppColors._();

  /// Primary (brand blue).
  static const Color primary = Color(0xFF3D9FDB);
  /// Primary strong / text-on-light.
  static const Color primaryStrong = Color(0xFF2F8FD0);
  /// Primary gradient CTA: `linear-gradient(135deg, accentCyan, primaryStrong)`.
  static const Color accentCyan = Color(0xFF5FC2E8);

  static const Color ink = Color(0xFF1C3F52); // text primary
  static const Color textSecondary = Color(0xFF4A90BB);
  static const Color textTertiary = Color(0xFF7FA6BC); // caption
  static const Color textMuted = Color(0xFF9DB8C9); // placeholder
  static const Color textMuted2 = Color(0xFFA9C5D6);

  static const Color divider = Color(0xFFE6F2F9);
  static const Color dividerStrong = Color(0xFFE0EEF6);

  static const Color surfaceTint1 = Color(0xFFF7FBFD);
  static const Color surfaceTint2 = Color(0xFFF2F8FC);
  static const Color surfaceTint3 = Color(0xFFEAF6FD);
  static const Color surfaceTint3Alt = Color(0xFFE7F5FC);
  static const Color selectedBorder = Color(0xFFBFE0F2);
  static const Color appBackground = Color(0xFFDCECF5); // outside the phone frame

  static const Color accentWarm = Color(0xFFF0A83A); // day-2 badge, filled bookmark
  static const Color accentWarmAlt = Color(0xFFE2A45F);

  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoSymbol = Color(0xFF3C1E1E);

  static const Color danger = Color(0xFFE2685F); // destructive confirm
  static const Color overlay = Color(0x66142837); // rgba(20,40,55,.4)

  /// Legacy aliases kept so earlier-written screens compile unchanged while
  /// the rest of the app is brought in line with the handoff token names.
  static const Color surfaceTint = surfaceTint3;
  static const Color surfaceSoft = appBackground;
  static const Color surfaceFaint = surfaceTint1;
  static const Color coral = danger;

  /// The exact shadow RGB from the handoff (`rgba(58,159,216,.07)` etc.) --
  /// close to but not identical to [primary], kept as its own token.
  static const Color _shadowRgb = Color(0xFF3A9FD8);

  /// Card shadow: `0 4px 14px rgba(58,159,216,.07)`.
  static List<BoxShadow> cardShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4)),
      ];

  /// Floating icon-button shadow: `0 3px 8px rgba(58,159,216,.15)`.
  static List<BoxShadow> floatingButtonShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
      ];

  /// Bottom-sheet shadow: `0 -12px 30px rgba(30,60,80,.15)`.
  static List<BoxShadow> bottomSheetShadow() => [
        BoxShadow(color: const Color(0xFF1E3C50).withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -12)),
      ];

  /// Generic soft primary-tinted shadow (used where the handoff doesn't
  /// specify an exact card/sheet value, e.g. custom hero elements).
  static List<BoxShadow> softShadow({
    double opacity = 0.18,
    double blurRadius = 18,
    Offset offset = const Offset(0, 8),
  }) {
    return [
      BoxShadow(
        color: primary.withValues(alpha: opacity),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accentCyan,
      onSecondary: AppColors.ink,
      error: AppColors.coral,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surfaceTint,
      primaryContainer: AppColors.surfaceSoft,
      onPrimaryContainer: AppColors.ink,
    );

    final textTheme = ThemeData.light().textTheme.apply(
          fontFamily: 'MPLUSRounded1c',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceFaint,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceFaint,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Solid approximation of the handoff's CTA gradient
          // (linear-gradient(135deg, accentCyan, primaryStrong)) -- Material
          // buttons don't support gradient fills without custom painting, so
          // this anchors on the gradient's darker end.
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          elevation: 6,
          shadowColor: AppColors.primaryStrong.withValues(alpha: 0.35),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceTint,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.surfaceSoft, space: 1),
    );
  }
}

/// Spacing scale used across screens so paddings stay consistent
/// without hardcoding magic numbers everywhere.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
