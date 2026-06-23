import 'package:flutter/material.dart';

import 'mushaf_palette.dart';

/// App-wide font faces + theme entry points. The actual reading **surfaces** are
/// the day-phase palettes in [MushafPalette] ("Light of Day"); the cubit picks
/// the active one. `light()`/`dark()` here are convenience anchors (Duha / Isha).
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

  // Hindi translation face — Noto Sans Devanagari (crisp, consistent across
  // devices rather than relying on the platform Devanagari font).
  static const String hindiFontFamily = 'NotoSansDevanagari';

  // Display serif for Latin headings (the surah English name in the chapter
  // header). Playfair Display (SIL OFL). Swap here to change the heading face.
  static const String displayFontFamily = 'PlayfairDisplay';

  /// The bright-midday surface — the default light theme anchor.
  static ThemeData light() => MushafPalette.of(DayPhase.duha).toTheme();

  /// The deep-night surface — the default dark theme anchor.
  static ThemeData dark() => MushafPalette.of(DayPhase.isha).toTheme();
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
  /// nastaliq face and extra line height; Hindi a Devanagari face; other
  /// languages use [base] unchanged.
  TextStyle scriptStyle(TextStyle base) {
    switch (this) {
      case 'ur':
        return base.copyWith(
          fontFamily: AppTheme.urduFontFamily,
          height: 2.0,
        );
      case 'hi':
        return base.copyWith(
          fontFamily: AppTheme.hindiFontFamily,
          height: 1.7,
        );
      default:
        return base;
    }
  }
}
