import 'package:flutter/material.dart';

/// Design tokens from the Voylog design handoff v2
/// (`Voylog UI/design_handoff_voylog_app/README.md`) -- teal palette,
/// Pretendard, pill-shaped controls, teal-tinted shadows. Values here are
/// copied verbatim from the handoff's Design Tokens table so screens stay
/// pixel-faithful to the reference.
///
/// v1 was a sky-blue palette on M PLUS Rounded 1c. Every token name from then
/// is kept here, pointing at its teal counterpart, so the 26 screens that only
/// change colour follow this one file instead of being edited one by one.
class AppColors {
  AppColors._();

  // --- Brand (teal) ------------------------------------------------------
  /// `primary-600` -- primary buttons, active tab, links.
  static const Color primary = Color(0xFF158A92);

  /// `primary-700` -- the home header's 분석하기 button.
  static const Color primaryStrong = Color(0xFF127C85);

  /// `primary-550` -- chip text, icon strokes.
  static const Color primaryChip = Color(0xFF148A90);

  /// `primary-500` -- brand default for icons, badges, emphasis.
  static const Color primaryBrand = Color(0xFF169AA4);

  /// `primary-400` -- numbered badges. In v1 this name held the light end of
  /// the CTA gradient, which v2 replaces with a solid fill.
  static const Color accentCyan = Color(0xFF2BB3B8);

  /// `primary-300` -- secondary icon strokes.
  static const Color primarySoft = Color(0xFF85B5B8);

  /// `primary-200` -- dashed "add" borders, emphasised card borders.
  static const Color selectedBorder = Color(0xFFBDE2E1);

  /// `primary-150` -- input and chip borders.
  static const Color inputBorder = Color(0xFFD6ECEC);

  /// `primary-100` -- active tab pill, badge backgrounds.
  static const Color surfaceTint3 = Color(0xFFE6F5F4);

  /// `primary-75` -- icon box backgrounds.
  static const Color surfaceTint3Alt = Color(0xFFE8F6F5);

  /// `primary-50` -- hashtag chip backgrounds.
  static const Color surfaceHashtag = Color(0xFFEEF8F8);

  // --- Surfaces ----------------------------------------------------------
  /// `surface-tint` -- secondary buttons and fields.
  static const Color surfaceTint2 = Color(0xFFF1F8F8);

  /// `surface-subtle` -- list cards.
  static const Color surfaceTint1 = Color(0xFFF7FBFB);

  /// `surface-page` -- screen and sheet background.
  static const Color surfacePage = Color(0xFFF8FBFB);

  /// `bg-app` -- outside the phone frame, and placeholder stripes.
  static const Color appBackground = Color(0xFFE9EEF0);

  // --- Text (teal-gray) --------------------------------------------------
  /// `primary-900` -- headings and body text.
  static const Color ink = Color(0xFF0F3440);
  static const Color textSecondary = Color(0xFF2F7F86);
  static const Color textTertiary = Color(0xFF5F7F85);
  static const Color textMuted = Color(0xFF8EA6AB);

  /// `text-disabled` -- inactive tab icons and labels.
  static const Color textMuted2 = Color(0xFFA3BCC0);

  // --- Lines -------------------------------------------------------------
  /// `divider` -- 1px separators.
  static const Color divider = Color(0xFFE2EEEF);

  /// `border` -- 1.5px card borders. (v1 name: dividerStrong.)
  static const Color dividerStrong = Color(0xFFE5F1F1);

  /// `border-strong` -- inactive icon strokes.
  static const Color borderStrong = Color(0xFFC5D8DA);

  // --- Semantic ----------------------------------------------------------
  static const Color danger = Color(0xFFE2554F); // active heart, delete, error
  static const Color dangerBg = Color(0xFFFDF1F0);
  static const Color warningIcon = Color(0xFFE8A13A);
  static const Color warningBg = Color(0xFFFFF4D6);
  static const Color warningText = Color(0xFF8A5D14);
  static const Color success = Color(0xFF5FC2A0); // "영업중" badge

  /// `accent-orange` -- day-2 colour, filled bookmark icon.
  static const Color accentWarm = Color(0xFFF0A83A);
  static const Color accentCoral = Color(0xFFD9784F); // cons badge, avatar
  static const Color accentCoralBg = Color(0xFFFDF1EA);

  /// v1's name for a second warm tone; v2 uses the coral accent there.
  static const Color accentWarmAlt = accentCoral;

  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoSymbol = Color(0xFF3A2B1A);

  static const Color overlay = Color(0x66142837); // rgba(20,40,55,.4)
  static const Color toast = ink;

  /// Legacy aliases kept so earlier-written screens compile unchanged.
  static const Color surfaceTint = surfaceTint3;
  static const Color surfaceSoft = appBackground;
  static const Color surfaceFaint = surfacePage;
  static const Color coral = danger;

  // --- Gradients ---------------------------------------------------------
  /// The home header. v2 drops the CTA gradient entirely -- full-width
  /// buttons are a solid [primary] now -- so these three are the only
  /// gradients the handoff still specifies.
  static const LinearGradient homeHeaderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF28ABB5), Color(0xFF1F9CA6), Color(0xFF1B919B)],
    stops: [0.0, 0.6, 1.0],
  );

  /// The onboarding background.
  static const LinearGradient introGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF169EAB), Color(0xFF1FA8B3), Color(0xFF3BB9BE)],
    stops: [0.0, 0.45, 1.0],
  );

  /// The "분석 중" background.
  static const LinearGradient analyzingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF14939D), Color(0xFF0F7A84), Color(0xFF0B5F67)],
    stops: [0.0, 0.55, 1.0],
  );

  // --- Shadows -----------------------------------------------------------
  /// The teal the handoff's shadows are tinted with, `rgba(22,154,164,...)`.
  static const Color _shadowRgb = Color(0xFF169AA4);

  /// The darker teal the primary/CTA shadows use, `rgba(21,138,146,...)`.
  static const Color _ctaShadowRgb = Color(0xFF158A92);

  /// `sh-card`: `0 4px 14px rgba(22,154,164,.10)`.
  static List<BoxShadow> cardShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
      ];

  /// `sh-card-soft`: `0 4px 14px rgba(22,154,164,.07)` -- list cards.
  static List<BoxShadow> cardSoftShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4)),
      ];

  /// `sh-field`: `0 3px 10px rgba(22,154,164,.08)`.
  static List<BoxShadow> fieldShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
      ];

  /// `sh-icon-btn`: `0 3px 8px rgba(22,154,164,.15)`.
  static List<BoxShadow> floatingButtonShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
      ];

  /// `sh-back-btn`: `0 4px 12px rgba(22,154,164,.12)`.
  static List<BoxShadow> backButtonShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
      ];

  /// `sh-primary`: `0 6px 14px rgba(21,138,146,.28)` -- small primary buttons.
  static List<BoxShadow> primaryShadow() => [
        BoxShadow(color: _ctaShadowRgb.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
      ];

  /// `sh-cta`: `0 10px 22px rgba(21,138,146,.35)` -- full-width CTA.
  static List<BoxShadow> ctaShadow() => [
        BoxShadow(color: _ctaShadowRgb.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10)),
      ];

  /// `sh-fab`: `0 12px 24px rgba(21,138,146,.40)`.
  static List<BoxShadow> fabShadow() => [
        BoxShadow(color: _ctaShadowRgb.withValues(alpha: 0.40), blurRadius: 24, offset: const Offset(0, 12)),
      ];

  /// `sh-tabbar`: `0 -6px 20px rgba(22,154,164,.08)`.
  static List<BoxShadow> tabBarShadow() => [
        BoxShadow(color: _shadowRgb.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -6)),
      ];

  /// `sh-sheet`: `0 -12px 30px rgba(30,60,80,.15)`.
  static List<BoxShadow> bottomSheetShadow() => [
        BoxShadow(color: const Color(0xFF1E3C50).withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -12)),
      ];

  /// Generic soft primary-tinted shadow, for elements the handoff gives no
  /// exact value for.
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

/// The corner radii the handoff names, so screens stop hardcoding them.
class AppRadius {
  AppRadius._();

  static const double pill = 999;
  static const double sheet = 28;
  static const double cta = 26; // full-width CTA (height/2 of a 52px button)
  static const double xl = 22;
  static const double card = 20;
  static const double lg = 18; // map boxes, dashed add buttons
  static const double md = 16; // banners, 64px thumbnails
  static const double sm = 14; // active tab pill, trip file icon
  static const double xs = 12; // 36px back button, hashtag chip
  static const double xxs = 10; // 30px icon buttons
}

class AppTheme {
  AppTheme._();

  /// The bundled typeface, named once so screens never spell it out.
  /// v2 moves from M PLUS Rounded 1c to Pretendard (static weights from the
  /// official OFL release -- the handoff ships a `.woff2`, which Flutter
  /// cannot load).
  static const String fontFamily = 'Pretendard';

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accentCyan,
      onSecondary: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surfaceTint,
      primaryContainer: AppColors.surfaceTint3,
      onPrimaryContainer: AppColors.ink,
    );

    final textTheme = ThemeData.light().textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfacePage,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfacePage,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // v2 drops the CTA gradient: a full-width button is solid
          // `primary-600` with `sh-cta` beneath it.
          backgroundColor: AppColors.primary,
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
          side: const BorderSide(color: AppColors.selectedBorder),
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
        fillColor: AppColors.surfaceTint2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceTint2,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      // Material 3 tints a dialog's surface with the seed colour, which
      // came out a murky green next to the rest of the app. The handoff has
      // no dialog of its own, so these follow its sheet/card values: white,
      // radius 20, an 800/18 title.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.textTertiary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfacePage,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.toast,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
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

  /// The handoff's screen side margin (the home sheet and header use 24).
  static const double screenGutter = 20;
}

/// Bounds the OS text-size setting the app honours.
///
/// The setting scales text and nothing else -- icons, avatars and the
/// fixed-size badges the handoff specifies stay put -- so past a point the
/// labels outgrow the rows they sit in and the type/icon ratio no longer
/// matches the design. Clamping keeps a larger setting readable without
/// letting the layout come apart, and still gives someone who needs bigger
/// text most of what they asked for.
class AppTextScaling {
  AppTextScaling._();

  static const double min = 0.9;
  static const double max = 1.15;

  /// Drop-in for `MaterialApp.builder`.
  static Widget wrap(BuildContext context, Widget? child) =>
      MediaQuery.withClampedTextScaling(
        minScaleFactor: min,
        maxScaleFactor: max,
        child: child ?? const SizedBox.shrink(),
      );
}
