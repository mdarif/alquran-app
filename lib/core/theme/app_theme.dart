import 'package:flutter/material.dart';

/// MVP theme. Dark/night mode is deferred (PRD 3.2 / backlog).
class AppTheme {
  AppTheme._();

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

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF12705B), // Al Marfa green
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFBF9F3), // warm off-white
    );
  }
}

/// Canonical Arabic (Madani/Uthmani) text style. Callers layer on size/height
/// via [TextStyle.copyWith], e.g. `QuranTextStyle.madani.copyWith(fontSize: 28)`.
class QuranTextStyle {
  QuranTextStyle._();

  static const TextStyle madani = TextStyle(
    fontFamily: AppTheme.arabicFontFamily,
    fontFeatures: AppTheme.arabicFontFeatures,
    color: Color(0xFF1A1A1A),
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
