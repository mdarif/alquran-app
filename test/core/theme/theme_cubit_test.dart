import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _at(int hour) => DateTime(2026, 6, 23, hour);

Future<ThemeCubit> _cubit({
  Map<String, Object> prefs = const {},
  int hour = 10,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final cubit = ThemeCubit(
    await SharedPreferences.getInstance(),
    clock: () => _at(hour),
  );
  addTearDown(cubit.close); // cancel the auto ticker
  return cubit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeCubit — Light of Day', () {
    test('defaults to auto, resolving the phase from the clock', () async {
      final cubit = await _cubit(hour: 10); // morning
      expect(cubit.isAuto, isTrue);
      expect(cubit.activePhase, DayPhase.duha);
    });

    test('auto resolves each part of the day', () async {
      expect((await _cubit(hour: 6)).activePhase, DayPhase.fajr);
      expect((await _cubit(hour: 11)).activePhase, DayPhase.duha);
      expect((await _cubit(hour: 15)).activePhase, DayPhase.asr);
      expect((await _cubit(hour: 18)).activePhase, DayPhase.maghrib);
      expect((await _cubit(hour: 23)).activePhase, DayPhase.isha);
      expect((await _cubit(hour: 2)).activePhase, DayPhase.isha);
    });

    test('reads a persisted fixed light on construction', () async {
      final cubit = await _cubit(prefs: {'theme_choice': 'isha'}, hour: 10);
      expect(cubit.isAuto, isFalse);
      expect(cubit.activePhase, DayPhase.isha);
    });

    test('setPhase holds a single light and persists it', () async {
      final cubit = await _cubit(hour: 10);
      await cubit.setPhase(DayPhase.maghrib);
      expect(cubit.isAuto, isFalse);
      expect(cubit.activePhase, DayPhase.maghrib);

      // A fresh cubit (even at a different hour) sees the held light.
      SharedPreferences.setMockInitialValues(const {'theme_choice': 'maghrib'});
      final reopened = ThemeCubit(
        await SharedPreferences.getInstance(),
        clock: () => _at(2),
      );
      addTearDown(reopened.close);
      expect(reopened.isAuto, isFalse);
      expect(reopened.activePhase, DayPhase.maghrib);
    });

    test('setAuto returns to following the day and persists', () async {
      final cubit = await _cubit(prefs: {'theme_choice': 'fajr'}, hour: 15);
      expect(cubit.isAuto, isFalse);
      await cubit.setAuto();
      expect(cubit.isAuto, isTrue);
      expect(cubit.activePhase, DayPhase.asr); // resolved from the 15:00 clock

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_choice'), 'auto');
    });

    test('setAuto while already auto stays auto', () async {
      final cubit = await _cubit(hour: 11);
      await cubit.setAuto();
      expect(cubit.isAuto, isTrue);
      expect(cubit.activePhase, DayPhase.duha);
    });

    test('refresh() re-resolves the surface as the day moves (auto)', () async {
      var hour = 10; // morning
      SharedPreferences.setMockInitialValues(const {});
      final cubit = ThemeCubit(
        await SharedPreferences.getInstance(),
        clock: () => _at(hour),
      );
      addTearDown(cubit.close);
      expect(cubit.activePhase, DayPhase.duha);

      hour = 18; // dusk — what the ticker / app-resume would catch
      cubit.refresh();
      expect(cubit.activePhase, DayPhase.maghrib);
    });

    test('refresh() is a no-op while holding a fixed light', () async {
      var hour = 10;
      SharedPreferences.setMockInitialValues(const {'theme_choice': 'isha'});
      final cubit = ThemeCubit(
        await SharedPreferences.getInstance(),
        clock: () => _at(hour),
      );
      addTearDown(cubit.close);

      hour = 11; // moved into Duha territory, but we're holding Isha
      cubit.refresh();
      expect(cubit.isAuto, isFalse);
      expect(cubit.activePhase, DayPhase.isha);
    });

    test('a corrupt persisted value falls back gracefully', () async {
      final cubit = await _cubit(prefs: {'theme_choice': 'banana'}, hour: 10);
      expect(cubit.isAuto, isFalse);
      expect(cubit.activePhase, DayPhase.duha); // safe default
    });
  });

  group('ThemeState equality', () {
    ThemeState s(DayPhase p, {required bool auto}) =>
        ThemeState(palette: MushafPalette.of(p), auto: auto);

    test('equal by phase + auto, differ otherwise', () {
      expect(s(DayPhase.duha, auto: true), s(DayPhase.duha, auto: true));
      expect(
        s(DayPhase.duha, auto: true).hashCode,
        s(DayPhase.duha, auto: true).hashCode,
      );
      expect(
        s(DayPhase.duha, auto: true),
        isNot(s(DayPhase.duha, auto: false)),
      );
      expect(
        s(DayPhase.duha, auto: true),
        isNot(s(DayPhase.isha, auto: true)),
      );
    });
  });
}
