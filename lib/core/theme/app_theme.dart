import 'package:flutter/material.dart';

/// MVP theme. Dark/night mode is deferred (PRD 3.2 / backlog).
class AppTheme {
  AppTheme._();

  // Primary Arabic face (PRD 4.1). Falls back gracefully if the .ttf is not
  // yet bundled in assets/fonts/.
  static const String arabicFontFamily = 'UthmanicHafs';

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
