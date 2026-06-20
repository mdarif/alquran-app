import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ThemeCubit> _cubit() async {
  SharedPreferences.setMockInitialValues(const {});
  return ThemeCubit(await SharedPreferences.getInstance());
}

Future<ThemeCubit> _cubitSeededDark() async {
  SharedPreferences.setMockInitialValues(const {'theme_mode': 'dark'});
  return ThemeCubit(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeCubit', () {
    test('defaults to light', () async {
      expect((await _cubit()).state, ThemeMode.light);
    });

    test('reads a persisted dark mode on construction', () async {
      expect((await _cubitSeededDark()).state, ThemeMode.dark);
    });

    test('toggle switches light → dark and persists', () async {
      final cubit = await _cubit();
      await cubit.toggle();
      expect(cubit.state, ThemeMode.dark);

      // A fresh cubit sees the persisted value.
      final reopened = ThemeCubit(await SharedPreferences.getInstance());
      expect(reopened.state, ThemeMode.dark);
    });

    test('toggle switches dark → light', () async {
      final cubit = await _cubitSeededDark();
      await cubit.toggle();
      expect(cubit.state, ThemeMode.light);
    });

    test('setMode to the current mode is a no-op (no emit)', () async {
      final cubit = await _cubit();
      final emissions = <ThemeMode>[];
      cubit.stream.listen(emissions.add);
      await cubit.setMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isEmpty);
    });
  });
}
