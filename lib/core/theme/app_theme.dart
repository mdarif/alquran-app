import 'package:flutter/material.dart';

/// App theme. Light is the default; dark is user-toggleable (see ThemeCubit).
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF12705B); // Al Marfa green

  // Primary Arabic face (PRD 4.1). Falls back gracefully if the .ttf is not
  // yet bundled in assets/fonts/.
  static const String arabicFontFamily = 'UthmanicHafs';

  // Arabic shaping features, requested defensively. With the V2 (Ver 0.18) face
  // the mandatory lam-alef ligature forms natively via `rlig`/default features;
  // enabling these explicitly keeps shaping correct across renderers.
  static const List<FontFeature> arabicFontFeatures = [
    FontFeature.enable('calt'),
    FontFeature.enable('rlig'),
    FontFeature.enable('liga'),
  ];

  // Urdu translation face — Noto Nastaliq Urdu (proper nastaliq script).
  static const String urduFontFamily = 'NotoNastaliqUrdu';

  // Display serif for Latin headings (the surah English name in the chapter
  // header). Playfair Display (SIL OFL). Swap here to change the heading face.
  static const String displayFontFamily = 'PlayfairDisplay';

  /// Gold accent reserved for sacred ornamentation (the Bismillah, and any
  /// future illuminated markers). Tuned per brightness for legibility: a deep
  /// antique gold on the light cream (≈4.3:1), a bright gold on the dark ground
  /// (≈11.5:1). Keep its use intentional — don't spread it across the UI.
  static Color ornamentGold(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFE6C76A)
          : const Color(0xFF9C6F02);

  static ThemeData light() => _build(
        Brightness.light,
        const Color(0xFFFBF9F3), // warm off-white
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        const Color(0xFF12100E), // warm near-black
      );

  static ThemeData _build(Brightness brightness, Color scaffold) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      // Flat, centered bar that blends into the warm page — drops the Material
      // "slab" look for a calmer, more premium reading frame.
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: base.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Canonical Arabic (Madani/Uthmani) text style. No colour — the text inherits
/// the theme's default (so it adapts to light/dark). Callers layer on size etc.
/// via [TextStyle.copyWith], e.g. `QuranTextStyle.madani.copyWith(fontSize: 28)`.
class QuranTextStyle {
  QuranTextStyle._();

  static const TextStyle madani = TextStyle(
    fontFamily: AppTheme.arabicFontFamily,
    fontFeatures: AppTheme.arabicFontFeatures,
    height: 1.9,
  );
}

/// Per-language script tuning for translation text.
extension TranslationTextStyle on String {
  /// A text style suited to this language code's script. Urdu needs a dedicated
  /// nastaliq face and extra line height; other languages use [base] unchanged.
  TextStyle scriptStyle(TextStyle base) {
    switch (this) {
      case 'ur':
        return base.copyWith(
          fontFamily: AppTheme.urduFontFamily,
          height: 2.0,
        );
      default:
        return base;
    }
  }
}
