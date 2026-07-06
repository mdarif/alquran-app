import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/home_page.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/hijri_date_line.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/presentation/widgets/last_read_banner.dart';
import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
import 'package:al_quran/features/surahs/presentation/pages/surah_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSurahRepository implements SurahRepository {
  @override
  Future<List<Surah>> getSurahs() async => const [
        Surah(
          id: 1,
          nameArabic: 'الفاتحة',
          nameEnglish: 'Al-Fatihah',
          totalAyahs: 7,
          revelationPlace: 'makkah',
        ),
      ];
}

class _FakeLastReadRepository implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null; // banner stays hidden
}

class _FakeIndexRepository implements IndexRepository {
  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async => const [];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  bool advancedNavigation = true,
  bool hijriDate = true,
  bool sunnahReminders = true,
  bool lastReadBanner = true,
  bool lightOfDay = true,
}) async {
  // A fixed light (not auto) so there's no Light-of-Day ticker to leak in tests.
  SharedPreferences.setMockInitialValues(const {'theme_choice': 'duha'});
  final theme = ThemeCubit(await SharedPreferences.getInstance());
  addTearDown(theme.close);
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: theme,
      child: MaterialApp(
        home: HomePage(
          advancedNavigation: advancedNavigation,
          hijriDate: hijriDate,
          sunnahReminders: sunnahReminders,
          lastReadBanner: lastReadBanner,
          lightOfDay: lightOfDay,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GetIt.I
      ..registerLazySingleton<SurahRepository>(_FakeSurahRepository.new)
      ..registerFactory<SurahListCubit>(
        () => SurahListCubit(GetIt.I<SurahRepository>()),
      )
      ..registerLazySingleton<LastReadRepository>(_FakeLastReadRepository.new)
      ..registerLazySingleton<IndexRepository>(_FakeIndexRepository.new)
      ..registerFactory<IndexListCubit>(
        () => IndexListCubit(GetIt.I<IndexRepository>()),
      );
  });
  tearDown(GetIt.I.reset);

  group('HomePage', () {
    testWidgets('is an immersive surah list with no tab bar', (tester) async {
      await _pumpHome(tester);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(SurahListBody), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });

    testWidgets('the Jump-to sheet offers Page/Juz/Hizb/Ruku', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(AppIcons.jumpMenu));
      await tester.pumpAndSettle();

      expect(find.text('Page'), findsOneWidget);
      expect(find.text('Juz'), findsOneWidget);
      expect(find.text('Hizb'), findsOneWidget);
      expect(find.text('Ruku'), findsOneWidget);
    });

    testWidgets('tapping a Jump option opens that index page', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(AppIcons.jumpMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juz'));
      await tester.pumpAndSettle();

      // The sheet is gone; the Juz index page is shown with its app-bar title.
      expect(find.widgetWithText(AppBar, 'Juz'), findsOneWidget);
    });

    testWidgets('the title is an invisible tap that opens About',
        (tester) async {
      await _pumpHome(tester);
      // No visible affordance — the title text itself is the tap target.
      await tester.tap(find.byKey(WidgetKeys.aboutButton));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.aboutPage), findsOneWidget);
    });

    testWidgets('hides the Jump button when advanced nav is off',
        (tester) async {
      await _pumpHome(tester, advancedNavigation: false);
      expect(find.byIcon(AppIcons.jumpMenu), findsNothing);
      expect(find.byType(SurahListBody), findsOneWidget);
    });

    testWidgets('surfaces the flagged features when their flags are on',
        (tester) async {
      await _pumpHome(tester); // all default to on
      expect(find.byType(HijriDateLine), findsOneWidget);
      expect(find.byType(LastReadBanner), findsOneWidget);
      // Reminders + Reading Light now live behind the app-bar overflow.
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);
    });

    testWidgets('the overflow menu opens Reading Light (and reveals its items)',
        (tester) async {
      await _pumpHome(tester); // ThemeCubit is provided → Reading Light shows
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      expect(find.text('Reading Light'), findsOneWidget);
      await tester.tap(find.text('Reading Light'));
      await tester.pumpAndSettle();
      // The Reading-Light sheet opened.
      expect(find.byType(ReadingLightSheet), findsOneWidget);
    });

    testWidgets('hides each flagged feature when its flag is off',
        (tester) async {
      await _pumpHome(
        tester,
        hijriDate: false,
        sunnahReminders: false,
        lastReadBanner: false,
        lightOfDay: false,
      );
      expect(find.byType(HijriDateLine), findsNothing);
      expect(find.byType(LastReadBanner), findsNothing);
      // No secondary controls → no overflow menu at all.
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsNothing);
      // The reading list itself is unaffected.
      expect(find.byType(SurahListBody), findsOneWidget);
    });
  });

  group('HomePage — app-bar search', () {
    testWidgets('search icon opens a search field and hides the other controls',
        (tester) async {
      await _pumpHome(tester);
      // Normal bar: title + overflow, no search field yet.
      expect(find.byKey(WidgetKeys.surahSearchField), findsNothing);
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.surahSearchButton));
      await tester.pumpAndSettle();

      // Search mode: field + back arrow show; the About title + overflow hide.
      expect(find.byKey(WidgetKeys.surahSearchField), findsOneWidget);
      expect(find.byKey(WidgetKeys.surahSearchBack), findsOneWidget);
      expect(find.byKey(WidgetKeys.aboutButton), findsNothing);
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsNothing);
    });

    testWidgets('typing filters the list; back exits and restores it',
        (tester) async {
      // Two surahs so filtering is observable.
      await _pumpHome(tester);
      expect(find.text('Al-Fatihah'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.surahSearchButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(WidgetKeys.surahSearchField), 'fatiha');
      await tester.pumpAndSettle();
      expect(find.text('Al-Fatihah'), findsOneWidget);

      // Back exits search, clears the query, and restores the normal bar.
      await tester.tap(find.byKey(WidgetKeys.surahSearchBack));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.surahSearchField), findsNothing);
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });
  });
}
