import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/feature_flags.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_theme.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
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
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _Repo implements AyahRepository {
  _Repo(this.settings);

  // The real repository reads the chosen script to pick the text column, so the
  // returned verse text differs per script — used to prove the view actually
  // re-renders the new script's text (not just swaps the font).
  final _Settings settings;
  int getAyahsCalls = 0;
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    getAyahsCalls++;
    final s = target.value;
    final txt = settings.script == ArabicScript.indopak ? 'IND' : 'UTH';
    return [
      Ayah(
        id: s * 100 + 1,
        surahId: s,
        ayahNumber: 1,
        textArabic: txt,
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

/// No-op player so ReaderPage's audio branch (behind FeatureFlags.audioRecitation)
/// can resolve an AyahAudioCubit from GetIt — these tests don't exercise audio.
class _SilentPlayer implements AyahRecitationPlayer {
  @override
  Stream<RecitationPlayback> get playbackStream =>
      const Stream<RecitationPlayback>.empty();
  @override
  Future<void> play(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late _Repo repo;
  late _Settings settings;

  setUp(() {
    settings = _Settings();
    repo = _Repo(settings);
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(repo, _LastRead()))
      ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));
  });
  tearDown(GetIt.I.reset);

  Future<void> pump(WidgetTester tester, [int surah = 2]) async {
    await tester.pumpWidget(
      MaterialApp(home: ReaderPage(target: ReaderTarget.surah(surah, 'S'))),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(WidgetKeys.settingsButton));
    await tester.pumpAndSettle();
  }

  // The Arabic font the reader is currently driving the Mushaf with — read off
  // the MushafView's threaded style (unambiguous; the rendering uses it).
  String? readerFont(WidgetTester tester) =>
      tester.widget<MushafView>(find.byType(MushafView)).arabicStyle.fontFamily;

  // The Arabic text the Detailed view is actually rendering — read off the first
  // AyahTile's ayah, proving the verses re-render (not just the font swaps).
  String detailedText(WidgetTester tester) =>
      tester.widget<AyahTile>(find.byType(AyahTile).first).ayah.textArabic;

  // The Arabic reading size the reader is currently driving the Mushaf with.
  double readerFontSize(WidgetTester tester) =>
      tester.widget<MushafView>(find.byType(MushafView)).arabicFontSize;

  // Tap one of the two script preview cards (Uthmani / IndoPak).
  Future<void> tapScript(WidgetTester tester, ArabicScript script) async {
    await tester.tap(find.byKey(WidgetKeys.scriptCard(script.name)));
    await tester.pumpAndSettle();
  }

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

        await tapScript(tester, ArabicScript.indopak);

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

        await tapScript(tester, ArabicScript.indopak);
        await tapScript(tester, ArabicScript.uthmani);

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
        await tapScript(tester, ArabicScript.indopak);

        final callsAfterSwitch = repo.getAyahsCalls;
        final setScriptAfterSwitch = settings.setScriptCalls;

        // Tap the already-selected segment again.
        await tapScript(tester, ArabicScript.indopak);

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
        await tapScript(tester, ArabicScript.indopak);
        // close the Display sheet (tap the scrim above it), then swipe
        await tester.tapAt(const Offset(400, 100));
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
        expect(detailedText(tester), 'UTH'); // Uthmani text initially

        await openPanel(tester);
        expect(find.byKey(WidgetKeys.scriptToggle), findsOneWidget);
        await tapScript(tester, ArabicScript.indopak);

        expect(settings.script, ArabicScript.indopak);
        // The verses themselves must re-render in the new script — not keep the
        // stale text from before the reload.
        expect(
          detailedText(tester),
          'IND',
          reason: 'Detailed view kept stale text after the script switch',
        );
      },
      skip: skip,
    );
  });

  group('font size steppers', () {
    testWidgets('A+ / A− nudge the reading size by one 2pt step',
        (tester) async {
      await pump(tester);
      await openPanel(tester);
      expect(readerFontSize(tester), 28); // default

      await tester.tap(find.byKey(WidgetKeys.fontIncrease));
      await tester.pumpAndSettle();
      expect(readerFontSize(tester), 30);

      await tester.tap(find.byKey(WidgetKeys.fontDecrease));
      await tester.pumpAndSettle();
      expect(readerFontSize(tester), 28);
    });

    testWidgets('A+ clamps at the maximum size', (tester) async {
      await pump(tester);
      await openPanel(tester);
      // More taps than steps to the max — must clamp, never overshoot.
      for (var i = 0; i < 14; i++) {
        await tester.tap(
          find.byKey(WidgetKeys.fontIncrease),
          warnIfMissed: false,
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(readerFontSize(tester), 48); // _maxFont
    });
  });

  testWidgets(
    'both script cards render with their labels',
    (tester) async {
      await pump(tester);
      await openPanel(tester);
      expect(
        find.byKey(WidgetKeys.scriptCard(ArabicScript.uthmani.name)),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKeys.scriptCard(ArabicScript.indopak.name)),
        findsOneWidget,
      );
      expect(find.textContaining('Uthmani/Madani'), findsOneWidget);
      expect(find.textContaining('IndoPak/Asian'), findsOneWidget);
      expect(find.textContaining('Madinah Mushaf'), findsOneWidget);
      expect(find.textContaining('South-Asian Naskh'), findsOneWidget);
    },
    skip: skip,
  );
}
