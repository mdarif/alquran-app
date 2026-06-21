import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/home_page.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
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
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final theme = ThemeCubit(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: theme,
      child: MaterialApp(
        home: HomePage(advancedNavigation: advancedNavigation),
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
      expect(find.byType(SurahListView), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });

    testWidgets('the Jump-to sheet offers Page/Juz/Hizb/Ruku', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Page'), findsOneWidget);
      expect(find.text('Juz'), findsOneWidget);
      expect(find.text('Hizb'), findsOneWidget);
      expect(find.text('Ruku'), findsOneWidget);
    });

    testWidgets('tapping a Jump option opens that index page', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juz'));
      await tester.pumpAndSettle();

      // The sheet is gone; the Juz index page is shown with its app-bar title.
      expect(find.widgetWithText(AppBar, 'Juz'), findsOneWidget);
    });

    testWidgets('hides the Jump button when advanced nav is off',
        (tester) async {
      await _pumpHome(tester, advancedNavigation: false);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsNothing);
      expect(find.byType(SurahListView), findsOneWidget);
    });
  });
}
