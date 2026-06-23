import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Proves the prayer-times integration seam without touching theme_cubit_test.dart
// (whose existing assertions must keep passing unchanged — no resolver there).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auto resolution prefers the injected phaseResolver', () async {
    SharedPreferences.setMockInitialValues(const {}); // auto
    final cubit = ThemeCubit(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 6, 23, 11), // hour-based would be Duha…
      phaseResolver: (_) => DayPhase.isha, // …but the resolver wins.
    );
    addTearDown(cubit.close);

    cubit.refresh(); // the ticker / app-resume path
    expect(cubit.activePhase, DayPhase.isha);
  });

  test('falls back to clock hours when no resolver is given', () async {
    SharedPreferences.setMockInitialValues(const {});
    final cubit = ThemeCubit(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 6, 23, 11),
    );
    addTearDown(cubit.close);

    cubit.refresh();
    expect(cubit.activePhase, DayPhase.duha); // phaseForHour(11)
  });
}
