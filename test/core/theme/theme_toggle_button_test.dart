import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app({required Brightness brightness}) async {
  SharedPreferences.setMockInitialValues(const {});
  final cubit = ThemeCubit(await SharedPreferences.getInstance());
  return BlocProvider<ThemeCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const Scaffold(
        appBar: null,
        body: ThemeToggleButton(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offers Dark mode while in light theme', (tester) async {
    await tester.pumpWidget(await _app(brightness: Brightness.light));
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
  });

  testWidgets('offers Light mode while in dark theme', (tester) async {
    await tester.pumpWidget(await _app(brightness: Brightness.dark));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('tap toggles the theme mode', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final cubit = ThemeCubit(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(body: ThemeToggleButton()),
        ),
      ),
    );

    expect(cubit.state, ThemeMode.light);
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pump();
    expect(cubit.state, ThemeMode.dark);
  });
}
