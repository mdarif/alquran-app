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
    return base.copyWith(scaffoldBackgroundColor: scaffold);
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
