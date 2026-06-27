import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A FIXED-phase cubit: it has no auto ticker, so widget tests don't leak a
// pending Timer. (The auto/Light-of-Day logic is covered in theme_cubit_test.)
Future<ThemeCubit> _fixed(DayPhase phase) async {
  SharedPreferences.setMockInitialValues({'theme_choice': phase.name});
  final cubit = ThemeCubit(await SharedPreferences.getInstance());
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _pump(WidgetTester tester, ThemeCubit cubit) {
  return tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: cubit,
      child: MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [ThemeToggleButton()])),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('icon reflects the current light — sun by day', (tester) async {
    await _pump(tester, await _fixed(DayPhase.duha));
    expect(find.byIcon(AppIcons.phaseDuha), findsOneWidget);
  });

  testWidgets('icon reflects the current light — moon at night',
      (tester) async {
    await _pump(tester, await _fixed(DayPhase.isha));
    expect(find.byIcon(AppIcons.phaseIsha), findsOneWidget);
  });

  testWidgets('opens the light sheet with Light of Day + every phase',
      (tester) async {
    await _pump(tester, await _fixed(DayPhase.duha));
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.text('Light of Day'), findsOneWidget);
    for (final p in DayPhase.values) {
      expect(find.text(p.label), findsOneWidget);
    }
  });

  testWidgets('picking a light holds that phase', (tester) async {
    final cubit = await _fixed(DayPhase.duha);
    await _pump(tester, cubit);
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Isha'));
    await tester.pumpAndSettle();

    expect(cubit.isAuto, isFalse);
    expect(cubit.activePhase, DayPhase.isha);
  });

  testWidgets('the auto card shows the live phase when following the day',
      (tester) async {
    // An AUTO cubit (default) runs a ticker — close it inside the body, since the
    // pending-timer invariant is checked before addTearDown runs.
    SharedPreferences.setMockInitialValues(const {});
    final cubit = ThemeCubit(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 6, 23, 11), // Duha
    );
    await _pump(tester, cubit);
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Following the day'), findsOneWidget);
    // "now Duha" on the auto card + the Duha swatch label.
    expect(find.textContaining('Duha'), findsWidgets);

    await cubit.close(); // cancel the auto ticker
  });
}
