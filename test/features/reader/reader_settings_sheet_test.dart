import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReaderSettingsSheet', () {
    late ThemeCubit themeCubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      themeCubit = ThemeCubit(await SharedPreferences.getInstance());
    });

    Future<void> pump(
      WidgetTester tester, {
      double fontSize = 28,
      bool detailed = false,
      ValueChanged<double>? onFontSize,
      ValueChanged<bool>? onDetailedChanged,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ThemeCubit>.value(
              value: themeCubit,
              child: ReaderSettingsSheet(
                fontSize: fontSize,
                minFont: 20,
                maxFont: 48,
                detailed: detailed,
                onFontSize: onFontSize ?? (_) {},
                onDetailedChanged: onDetailedChanged ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the theme, view, and text-size controls',
        (tester) async {
      await pump(tester);

      expect(find.text('Display'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('tapping Detailed reports the viewport change', (tester) async {
      bool? received;
      await pump(tester, onDetailedChanged: (v) => received = v);

      await tester.tap(find.text('Detailed'));
      await tester.pump();

      expect(received, isTrue);
    });

    testWidgets('dragging the slider reports a new font size', (tester) async {
      double? received;
      await pump(tester, onFontSize: (v) => received = v);

      await tester.drag(find.byType(Slider), const Offset(-100, 0));
      await tester.pump();

      expect(received, isNotNull);
    });

    testWidgets('tapping Dark switches the theme cubit to dark mode',
        (tester) async {
      await pump(tester);
      expect(themeCubit.state, ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(themeCubit.state, ThemeMode.dark);
    });
  });
}
