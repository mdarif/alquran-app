import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mushaf_palette.dart';

/// The resolved reading surface, plus whether we're in **Light of Day** (auto)
/// mode — so the picker can show what's selected.
@immutable
class ThemeState {
  const ThemeState({required this.palette, required this.auto});

  final MushafPalette palette;
  final bool auto;

  DayPhase get phase => palette.phase;

  @override
  bool operator ==(Object other) =>
      other is ThemeState &&
      other.palette.phase == palette.phase &&
      other.auto == auto;

  @override
  int get hashCode => Object.hash(palette.phase, auto);
}

/// Drives the theme. In **auto** mode the reading surface follows the clock
/// (later, the user's prayer times) — the signature "Light of Day". Otherwise it
/// holds a single light the reader chose. The choice is persisted; a light ticker
/// re-resolves the auto surface as the day moves.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(_initial(_prefs, clock ?? DateTime.now)) {
    if (state.auto) _startTicker();
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  Timer? _ticker;

  static const String _key = 'theme_choice'; // 'auto' | DayPhase.name

  static ThemeState _initial(
    SharedPreferences prefs,
    DateTime Function() clock,
  ) {
    final saved = prefs.getString(_key);
    if (saved != null && saved != 'auto') {
      final phase = DayPhase.values.firstWhere(
        (p) => p.name == saved,
        orElse: () => DayPhase.duha,
      );
      return ThemeState(palette: MushafPalette.of(phase), auto: false);
    }
    return ThemeState(
      palette: MushafPalette.of(MushafPalette.phaseForHour(clock().hour)),
      auto: true,
    );
  }

  bool get isAuto => state.auto;
  DayPhase get activePhase => state.phase;

  /// Follow the day (Light of Day).
  Future<void> setAuto() async {
    _startTicker();
    _resolveAuto(force: true);
    await _prefs.setString(_key, 'auto');
  }

  /// Hold a single light.
  Future<void> setPhase(DayPhase phase) async {
    _ticker?.cancel();
    _ticker = null;
    emit(ThemeState(palette: MushafPalette.of(phase), auto: false));
    await _prefs.setString(_key, phase.name);
  }

  /// Re-resolve the auto surface now (e.g. on app resume, after time has moved).
  void refresh() {
    if (state.auto) _resolveAuto();
  }

  void _resolveAuto({bool force = false}) {
    final phase = MushafPalette.phaseForHour(_clock().hour);
    if (!force && state.auto && state.phase == phase) return;
    emit(ThemeState(palette: MushafPalette.of(phase), auto: true));
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _resolveAuto(),
    );
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
