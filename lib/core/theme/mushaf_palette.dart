import 'package:flutter/material.dart';

import 'app_icons.dart';

/// The five reading "lights" of the day — the heart of **Light of Day**, where
/// the app's surface breathes with the rhythm of the day (and, later, the user's
/// prayer times). Each phase is a complete, hand-tuned palette, not a brightness
/// flip: a dawn that's soft on just-woken eyes, a crisp midday, a warming
/// afternoon, a golden Maghrib, and a deep, restful night.
enum DayPhase {
  fajr('Fajr', 'Dawn'),
  duha('Duha', 'Morning'),
  asr('Asr', 'Afternoon'),
  maghrib('Maghrib', 'Dusk'),
  isha('Isha', 'Night');

  const DayPhase(this.label, this.note);

  /// Short name (the prayer the light belongs to).
  final String label;

  /// A one-word feel, for the picker subtitle.
  final String note;
}

/// Carries the palette colours that Material's [ColorScheme] has no slot for —
/// chiefly the sacred [gold] used for ornamentation (Bismillah, illumination).
/// Read it with `Theme.of(context).extension<MushafColors>()!`.
@immutable
class MushafColors extends ThemeExtension<MushafColors> {
  const MushafColors({required this.gold});

  final Color gold;

  @override
  MushafColors copyWith({Color? gold}) => MushafColors(gold: gold ?? this.gold);

  @override
  MushafColors lerp(ThemeExtension<MushafColors>? other, double t) {
    if (other is! MushafColors) return this;
    return MushafColors(gold: Color.lerp(gold, other.gold, t)!);
  }
}

/// A single reading surface, hand-tuned per [DayPhase].
@immutable
class MushafPalette {
  const MushafPalette({
    required this.phase,
    required this.brightness,
    required this.background,
    required this.ink,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.gold,
  });

  final DayPhase phase;
  final Brightness brightness;

  /// The reading surface (scaffold + M3 surface).
  final Color background;

  /// Primary text (M3 onSurface).
  final Color ink;

  /// Brand/accent (M3 primary) — the green, tuned for legibility per surface.
  final Color accent;

  /// Verse-badge / chip fill + its text (M3 primaryContainer / onPrimaryContainer).
  final Color accentContainer;
  final Color onAccentContainer;

  /// Sacred ornamentation gold (via [MushafColors]).
  final Color gold;

  String get label => phase.label;

  /// Build a full Material 3 [ThemeData] for this surface. Mirrors the flat,
  /// centred, slab-free chrome the app already uses — only the palette changes.
  ThemeData toTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      surface: background,
      onSurface: ink,
      primary: accent,
      primaryContainer: accentContainer,
      onPrimaryContainer: onAccentContainer,
      onSurfaceVariant: ink.withValues(
        alpha: brightness == Brightness.dark ? 0.70 : 0.58,
      ),
    );
    final theme = ThemeData(useMaterial3: true, colorScheme: scheme);
    return theme.copyWith(
      scaffoldBackgroundColor: background,
      // Route the auto-generated AppBar leading/close buttons through the app's
      // icon family so they match the rest (the default is a platform glyph that
      // never goes through AppIcon).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const AppIcon(AppIcons.back),
        closeButtonIconBuilder: (_) => const AppIcon(AppIcons.close),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [MushafColors(gold: gold)],
    );
  }

  static MushafPalette of(DayPhase phase) => _all[phase]!;

  static List<MushafPalette> get ordered =>
      DayPhase.values.map((p) => _all[p]!).toList(growable: false);

  /// The phase whose light belongs to [hour] (0–23). Clock-based for now; will
  /// later snap to the user's actual prayer times.
  static DayPhase phaseForHour(int hour) {
    if (hour >= 5 && hour < 8) return DayPhase.fajr; // first light → sunrise
    if (hour >= 8 && hour < 14) return DayPhase.duha; // morning → midday
    if (hour >= 14 && hour < 17) return DayPhase.asr; // afternoon
    if (hour >= 17 && hour < 20) return DayPhase.maghrib; // sunset
    return DayPhase.isha; // night (20:00–04:59)
  }

  // --- The five lights (hand-tuned). ----------------------------------------
  static const Map<DayPhase, MushafPalette> _all = {
    // The blue hush before sunrise — soft, cool, low-contrast for just-woken eyes.
    DayPhase.fajr: MushafPalette(
      phase: DayPhase.fajr,
      brightness: Brightness.light,
      background: Color(0xFFEAEEF1),
      ink: Color(0xFF272D33),
      accent: Color(0xFF2E6B5E),
      accentContainer: Color(0xFFCEDFDC),
      onAccentContainer: Color(0xFF0F3E34),
      gold: Color(0xFF8A7A52),
    ),
    // Crisp, bright midday — the clean default reading surface.
    DayPhase.duha: MushafPalette(
      phase: DayPhase.duha,
      brightness: Brightness.light,
      background: Color(0xFFFBF9F3),
      ink: Color(0xFF1B1A18),
      accent: Color(0xFF12705B),
      accentContainer: Color(0xFFC9E7DC),
      onAccentContainer: Color(0xFF0B3A2E),
      gold: Color(0xFF9C6F02),
    ),
    // Warming afternoon cream.
    DayPhase.asr: MushafPalette(
      phase: DayPhase.asr,
      brightness: Brightness.light,
      background: Color(0xFFF6EEDD),
      ink: Color(0xFF2A2317),
      accent: Color(0xFF166E58),
      accentContainer: Color(0xFFCFE5D9),
      onAccentContainer: Color(0xFF0E3E30),
      gold: Color(0xFF8F6410),
    ),
    // Golden hour — a cosy, deepening parchment.
    DayPhase.maghrib: MushafPalette(
      phase: DayPhase.maghrib,
      brightness: Brightness.light,
      background: Color(0xFFF0E4CF),
      ink: Color(0xFF312817),
      accent: Color(0xFF155C49),
      accentContainer: Color(0xFFD3E0CF),
      onAccentContainer: Color(0xFF123E2D),
      gold: Color(0xFF875312),
    ),
    // Deep indigo night — restful for night reading.
    DayPhase.isha: MushafPalette(
      phase: DayPhase.isha,
      brightness: Brightness.dark,
      background: Color(0xFF0F1217),
      ink: Color(0xFFE7E1D4),
      accent: Color(0xFF54B79B),
      accentContainer: Color(0xFF1A463A),
      onAccentContainer: Color(0xFFBFE8DA),
      gold: Color(0xFFE6C76A),
    ),
  };
}
