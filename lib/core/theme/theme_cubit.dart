import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light/dark mode, persisted across launches. Light is the default.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._prefs) : super(_readMode(_prefs));

  final SharedPreferences _prefs;

  static const String _key = 'theme_mode';

  static ThemeMode _readMode(SharedPreferences prefs) =>
      prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggle() => setMode(
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
