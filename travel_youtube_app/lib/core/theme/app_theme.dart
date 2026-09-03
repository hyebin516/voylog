import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens lifted from the Voylog Claude Design prototype (soft sky-blue
/// palette, pill-shaped controls, blue-tinted shadows instead of grey).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F8FD0);
  static const Color ink = Color(0xFF1C3F52);
  static const Color accentCyan = Color(0xFF5FC2E8);
  static const Color coral = Color(0xFFE2554F);
  static const Color surfaceTint = Color(0xFFEAF6FD);
  static const Color surfaceSoft = Color(0xFFDCECF5);
  static const Color surfaceFaint = Color(0xFFF7FBFD);

  /// Soft primary-tinted shadow used on cards and primary buttons instead of
  /// Material's default grey elevation shadow.
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

    final textTheme = GoogleFonts.mPlusRounded1cTextTheme(
      ThemeData.light().textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

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
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          elevation: 6,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
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
