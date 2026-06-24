import 'package:al_quran/core/feature_flags.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_theme.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
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

class _Repo implements AyahRepository {
  int getAyahsCalls = 0;
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    getAyahsCalls++;
    final s = target.value;
    return [
      Ayah(
        id: s * 100 + 1,
        surahId: s,
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

class _LastRead implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

class _Settings implements ReaderSettingsRepository {
  ArabicScript _script = ArabicScript.uthmani;
  int setScriptCalls = 0;
  @override
  ArabicScript get script => _script;
  @override
  Future<void> setScript(ArabicScript value) async {
    setScriptCalls++;
    _script = value;
  }

  @override
  double fontSize = 28;
  @override
  bool detailed = false;
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

void main() {
  late _Repo repo;
  late _Settings settings;

  setUp(() {
    repo = _Repo();
    settings = _Settings();
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(repo, _LastRead()))
      ..registerLazySingleton<ReaderSettingsRepository>(() => settings);
  });
  tearDown(GetIt.I.reset);

  Future<void> pump(WidgetTester tester, [int surah = 2]) async {
    await tester.pumpWidget(
      MaterialApp(home: ReaderPage(target: ReaderTarget.surah(surah, 'S'))),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(WidgetKeys.fontSizeButton));
    await tester.pumpAndSettle();
  }

  // The Arabic font the reader is currently driving the Mushaf with — read off
  // the MushafView's threaded style (unambiguous; the rendering uses it).
  String? readerFont(WidgetTester tester) =>
      tester.widget<MushafView>(find.byType(MushafView)).arabicStyle.fontFamily;

  const skip = !FeatureFlags.indopakScript; // feature shipped dark

  group('IndoPak script toggle', () {
    testWidgets(
      'appears in the text-size panel and starts on Uthmani',
      (tester) async {
        await pump(tester);
        await openPanel(tester);
        expect(find.byKey(WidgetKeys.scriptToggle), findsOneWidget);
        // Defaults to Uthmani.
        expect(readerFont(tester), AppTheme.arabicFontFamily);
      },
      skip: skip,
    );

    testWidgets(
      'selecting IndoPak switches the verse font and persists',
      (tester) async {
        await pump(tester);
        await openPanel(tester);

        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();

        expect(settings.script, ArabicScript.indopak);
        expect(settings.setScriptCalls, 1);
        expect(readerFont(tester), AppTheme.indopakFontFamily); // Noorehuda
      },
      skip: skip,
    );

    testWidgets(
      'deselecting IndoPak (back to Uthmani) reverts the font',
      (tester) async {
        await pump(tester);
        await openPanel(tester);

        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Uthmani'));
        await tester.pumpAndSettle();

        expect(settings.script, ArabicScript.uthmani);
        expect(readerFont(tester), AppTheme.arabicFontFamily);
      },
      skip: skip,
    );

    testWidgets(
      're-selecting the active script is a no-op (no reload)',
      (tester) async {
        await pump(tester);
        await openPanel(tester);
        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();

        final callsAfterSwitch = repo.getAyahsCalls;
        final setScriptAfterSwitch = settings.setScriptCalls;

        // Tap the already-selected segment again.
        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();

        // No extra fetch or persist for re-selecting the active script.
        expect(repo.getAyahsCalls, callsAfterSwitch);
        expect(settings.setScriptCalls, setScriptAfterSwitch);
      },
      skip: skip,
    );

    testWidgets(
      'the chosen script persists across swipe navigation',
      (tester) async {
        await pump(tester, 2);
        await openPanel(tester);
        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();
        // dismiss the panel by tapping away, then swipe to the next surah
        await tester.tapAt(const Offset(200, 500));
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(MushafView),
          const Offset(-400, 0),
          1200,
        );
        await tester.pumpAndSettle();

        expect(find.text('Chapter 3'), findsWidgets); // navigated
        expect(readerFont(tester), AppTheme.indopakFontFamily); // still IndoPak
      },
      skip: skip,
    );

    testWidgets(
      'the toggle is available and works in the Detailed view too',
      (tester) async {
        await pump(tester);
        // Switch to Detailed view.
        await tester.tap(find.byKey(WidgetKeys.viewportToggle));
        await tester.pumpAndSettle();

        await openPanel(tester);
        expect(find.byKey(WidgetKeys.scriptToggle), findsOneWidget);
        await tester.tap(find.text('IndoPak'));
        await tester.pumpAndSettle();

        expect(settings.script, ArabicScript.indopak);
      },
      skip: skip,
    );
  });
}
