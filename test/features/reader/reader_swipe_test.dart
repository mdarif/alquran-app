import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Fake repo: one ayah per surah, headings named "Chapter N".
class _FakeAyahRepository implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final surahId = target.value; // surah dimension: value == surah id
    return [
      Ayah(
        id: surahId * 100 + 1,
        surahId: surahId,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
      ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var i = 1; i <= 114; i++)
          i: SurahHeading(number: i, nameEnglish: 'Chapter $i', totalAyahs: 3),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeLastReadRepository implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

/// Repo with two translations (Urdu + English) for the Detailed-view filter test.
class _FakeAyahRepoWithTranslations implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [
        Ayah(
          id: 201,
          surahId: 2,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          translations: {1: 'اردو متن', 3: 'english body'},
        ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        2: const SurahHeading(
          number: 2,
          nameEnglish: 'Al-Baqarah',
          totalAyahs: 3,
        ),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [
        TranslationResource(
          id: 1,
          languageCode: 'ur',
          name: 'Urdu',
          author: 'Junagarhi',
        ),
        TranslationResource(
          id: 3,
          languageCode: 'en',
          name: 'English',
          author: 'Khan',
        ),
      ];
}

class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({
    this.fontSize = 28,
    this.detailed = false,
    this.peekTranslation,
    this.detailedTranslations,
  });
  @override
  double fontSize;
  @override
  bool detailed;
  @override
  String? peekTranslation;
  @override
  List<String>? detailedTranslations;
  @override
  Future<void> setFontSize(double value) async => fontSize = value;
  @override
  Future<void> setDetailed(bool value) async => detailed = value;
  @override
  Future<void> setPeekTranslation(String value) async =>
      peekTranslation = value;
  @override
  Future<void> setDetailedTranslations(List<String> codes) async =>
      detailedTranslations = codes;
}

Future<void> _pumpReader(WidgetTester tester, ReaderTarget target) async {
  await tester.pumpWidget(MaterialApp(home: ReaderPage(target: target)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_FakeAyahRepository(), _FakeLastReadRepository()),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new);
  });
  tearDown(GetIt.I.reset);

  group('Reader swipe navigation', () {
    testWidgets('swipe left advances to the next surah', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.text('Chapter 2'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 3'), findsWidgets); // header + app bar
      expect(find.text('Chapter 2'), findsNothing);
    });

    testWidgets('swipe right goes to the previous surah', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(3, 'Ali Imran'));
      expect(find.text('Chapter 3'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsWidgets);
      expect(find.text('Chapter 3'), findsNothing);
    });

    testWidgets('swipe right on the first surah is a no-op (no wrap)',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(1, 'Al-Fatihah'));
      expect(find.text('Chapter 1'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1'), findsOneWidget); // unchanged
    });

    testWidgets('a short drag below the distance threshold does not navigate',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));

      // Small horizontal nudge (< threshold) should not change section.
      await tester.drag(find.byType(MushafView), const Offset(-30, 0));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('a mostly-vertical drag does not navigate', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));

      // Big vertical, small horizontal — a scroll, not a swipe.
      await tester.drag(find.byType(MushafView), const Offset(-40, 400));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsOneWidget);
    });
  });

  group('Reader default viewport', () {
    testWidgets('opens in Reading (Mushaf) view by default', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.byType(MushafView), findsOneWidget);
    });

    testWidgets('always opens in Reading view, even if detailed was last used',
        (tester) async {
      // The viewport is no longer restored from settings — every fresh open
      // (e.g. tapping a surah from the index) lands in Reading view.
      GetIt.I.unregister<ReaderSettingsRepository>();
      GetIt.I.registerLazySingleton<ReaderSettingsRepository>(
        () => _FakeSettings(detailed: true),
      );

      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.byType(MushafView), findsOneWidget);
    });
  });

  group('Detailed-view translation filter', () {
    testWidgets('toggling a language chip hides that translation',
        (tester) async {
      GetIt.I.unregister<ReaderCubit>();
      GetIt.I.registerFactory<ReaderCubit>(
        () => ReaderCubit(
          _FakeAyahRepoWithTranslations(),
          _FakeLastReadRepository(),
        ),
      );

      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));

      // Switch to Detailed view — both translations show.
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsOneWidget);

      // Open the translations filter and turn English off via its chip.
      await tester.tap(find.byTooltip('Translations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('english body'), findsNothing);
      expect(find.text('اردو متن'), findsOneWidget); // Urdu stays
    });

    testWidgets('the last remaining language cannot be turned off',
        (tester) async {
      GetIt.I.unregister<ReaderCubit>();
      GetIt.I.registerFactory<ReaderCubit>(
        () => ReaderCubit(
          _FakeAyahRepoWithTranslations(),
          _FakeLastReadRepository(),
        ),
      );

      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Translations'));
      await tester.pumpAndSettle();

      // Turn English off, then try to turn Urdu off too — it must stay.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(find.text('اردو متن'), findsOneWidget);
    });
  });
}
