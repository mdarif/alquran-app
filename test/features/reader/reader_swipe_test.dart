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

/// Repo with Urdu + Hindi (no English) — exercises the "device language not
/// available → fall back to Urdu" default, given the en test-host locale.
class _FakeAyahRepoUrHi implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [
        Ayah(
          id: 201,
          surahId: 2,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          translations: {1: 'اردو متن', 2: 'हिंदी अनुवाद'},
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
          id: 2,
          languageCode: 'hi',
          name: 'Hindi',
          author: 'al-Umari',
        ),
      ];
}

class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({
    this.fontSize = 28,
    this.detailed = false,
    this.selectedTranslations,
  });
  @override
  double fontSize;
  @override
  bool detailed;
  @override
  List<String>? selectedTranslations;
  @override
  Future<void> setFontSize(double value) async => fontSize = value;
  @override
  Future<void> setDetailed(bool value) async => detailed = value;
  @override
  Future<void> setSelectedTranslations(List<String> codes) async =>
      selectedTranslations = codes;
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
    // Register the translations repo + a settings fake with both editions
    // selected (the default is a single language), then open Detailed view.
    Future<void> openDetailed(
      WidgetTester tester, {
      List<String> selected = const ['ur', 'en'],
    }) async {
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(
            _FakeAyahRepoWithTranslations(),
            _FakeLastReadRepository(),
          ),
        )
        ..unregister<ReaderSettingsRepository>()
        ..registerLazySingleton<ReaderSettingsRepository>(
          () => _FakeSettings(selectedTranslations: selected),
        );
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
    }

    testWidgets('toggling a language chip hides that translation',
        (tester) async {
      await openDetailed(tester);
      // Both selected → both show, with the chip strip in the view.
      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsOneWidget);

      // Turn English off via its chip in the strip.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('english body'), findsNothing);
      expect(find.text('اردو متن'), findsOneWidget); // Urdu stays
    });

    testWidgets('the last remaining language cannot be turned off',
        (tester) async {
      await openDetailed(tester);

      // Turn English off, then try to turn Urdu off too — it must stay.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(find.text('اردو متن'), findsOneWidget);
    });

    testWidgets('× collapses the strip to a pill, tapping it expands again',
        (tester) async {
      await openDetailed(tester);
      expect(find.text('English'), findsOneWidget); // chip visible

      // Collapse via the × — chips hide, a summary pill appears.
      await tester.tap(find.byTooltip('Hide languages'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsNothing);
      expect(find.text('اردو · English'), findsOneWidget); // pill summary

      // Tap the pill to expand again.
      await tester.tap(find.text('اردو · English'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('the selection carries over to the Reading peek card',
        (tester) async {
      await openDetailed(tester);

      // Narrow to Urdu only in Detailed.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('english body'), findsNothing);

      // Back to Reading, tap the verse — the peek shows Urdu only (carried).
      await tester.tap(find.byTooltip('Reading view'));
      await tester.pumpAndSettle();
      final flow = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTapUp != null && w.onTap == null,
      );
      await tester.tap(flow.first);
      await tester.pumpAndSettle();

      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsNothing);
    });
  });

  group('Default translation selection', () {
    // No saved selection (the default _FakeSettings) → the reader resolves a
    // single default: the device language if we have that edition, else Urdu.
    Future<void> openDetailed(WidgetTester tester, AyahRepository repo) async {
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(repo, _FakeLastReadRepository()),
        );
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to the device language when that edition exists',
        (tester) async {
      // Test host locale is en, and English is available → default to English.
      await openDetailed(tester, _FakeAyahRepoWithTranslations());
      expect(find.text('english body'), findsOneWidget);
      expect(find.text('اردو متن'), findsNothing);
    });

    testWidgets('falls back to Urdu when the device language has no edition',
        (tester) async {
      // en host locale, but only Urdu + Hindi exist → fall back to Urdu.
      await openDetailed(tester, _FakeAyahRepoUrHi());
      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('हिंदी अनुवाद'), findsNothing);
    });
  });

  group('Last Read viewport resume', () {
    testWidgets('resumes in Detailed when that was the saved viewport',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(2, 'Al-Baqarah'),
            focusAyahId: 201,
            initialDetailed: true, // came from Detailed view
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Detailed view → no Mushaf flow.
      expect(find.byType(MushafView), findsNothing);
    });

    testWidgets('resumes in Reading when that was the saved viewport',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(2, 'Al-Baqarah'),
            focusAyahId: 201,
            initialDetailed: false, // came from Reading view
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MushafView), findsOneWidget);
    });
  });
}
