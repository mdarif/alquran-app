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
  _Repo(this.settings, {this.resources = const []});

  // The real repository reads the chosen script to pick the text column, so the
  // returned verse text differs per script — used to prove the view actually
  // re-renders the new script's text (not just swaps the font).
  final _Settings settings;
  final List<TranslationResource> resources;
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
        translations: {
          for (final resource in resources) resource.slug: 'Meaning',
        },
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
  Future<List<TranslationResource>> getTranslationResources() async =>
      resources;
}

class _LastRead implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

class _Settings implements ReaderSettingsRepository {
  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
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
  @override
  double recitationSpeed = 1.0;
  @override
  Future<void> setRecitationSpeed(double value) async =>
      recitationSpeed = value;
  @override
  bool showTranslationPeek = false;
  @override
  Future<void> setShowTranslationPeek(bool value) async =>
      showTranslationPeek = value;
  @override
  bool showArabicMatn = true;
  @override
  Future<void> setShowArabicMatn(bool value) async => showArabicMatn = value;
  @override
  bool translationAudioDuringContinuousPlayback = true;
  @override
  Future<void> setTranslationAudioDuringContinuousPlayback(bool value) async =>
      translationAudioDuringContinuousPlayback = value;

  int resetCalls = 0;
  @override
  Future<void> resetToDefaults() async {
    resetCalls++;
    _script = ArabicScript.uthmani;
    fontSize = ReaderSettingsRepository.defaultFontSize;
    selectedTranslations = null;
    showTranslationPeek = false;
    showArabicMatn = true;
  }
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
  Future<void> prefetch(int ayahId) async {}
  @override
  Stream<PlaybackProgress> get progressStream =>
      const Stream<PlaybackProgress>.empty();
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  double get speed => 1.0;
  @override
  Future<void> setLoopMode(RecitationLoop mode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

const List<TranslationResource> _translationResources = [
  TranslationResource(
    id: 1,
    slug: 'ur-junagarhi',
    languageCode: 'ur',
    name: 'Muhammad Junagarhi',
    nativeName: 'اردو',
    author: 'Muhammad Junagarhi',
    direction: 'rtl',
    sortOrder: 1,
    defaultOn: true,
  ),
];

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
  // skipOffstage: false — Settings is now a full-screen page ON TOP of the
  // reader, not a bottom sheet, so the reader route is offstage while it's open.
  String? readerFont(WidgetTester tester) => tester
      .widget<MushafView>(find.byType(MushafView, skipOffstage: false))
      .arabicStyle
      .fontFamily;

  // The Arabic text the Detailed view is actually rendering — read off the first
  // AyahTile's ayah, proving the verses re-render (not just the font swaps).
  String detailedText(WidgetTester tester) => tester
      .widget<AyahTile>(find.byType(AyahTile, skipOffstage: false).first)
      .ayah
      .textArabic;

  // The Arabic reading size the reader is currently driving the Mushaf with.
  double readerFontSize(WidgetTester tester) => tester
      .widget<MushafView>(find.byType(MushafView, skipOffstage: false))
      .arabicFontSize;

  // Tap one of the two script preview cards (Uthmani / IndoPak).
  Future<void> tapScript(WidgetTester tester, ArabicScript script) async {
    await tester.tap(find.byKey(WidgetKeys.scriptCard(script.name)));
    await tester.pumpAndSettle();
  }

  testWidgets('the text-size controls update the reader without a preview card',
      (tester) async {
    await pump(tester);
    await openPanel(tester);

    expect(find.byKey(WidgetKeys.textSizePreview), findsNothing);
    final before = readerFontSize(tester);
    await tester.tap(find.byKey(WidgetKeys.fontIncrease));
    await tester.pumpAndSettle();
    expect(readerFontSize(tester), greaterThan(before));
  });

  testWidgets('reading translation peek setting is hidden while flagged off',
      (tester) async {
    await GetIt.I.reset();
    settings = _Settings();
    repo = _Repo(settings, resources: _translationResources);
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(repo, _LastRead()))
      ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));

    await pump(tester);
    await openPanel(tester);

    expect(FeatureFlags.readingTranslationPeek, isFalse);
    expect(find.text('Show translation'), findsNothing);
    expect(find.byKey(WidgetKeys.translationPeekToggle), findsNothing);
  });

  testWidgets('saved translation peek preference is ignored while flagged off',
      (tester) async {
    await GetIt.I.reset();
    settings = _Settings()..showTranslationPeek = true;
    repo = _Repo(settings, resources: _translationResources);
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(repo, _LastRead()))
      ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));

    await pump(tester);
    await tester.tap(find.byType(MushafView));
    await tester.pumpAndSettle();

    expect(FeatureFlags.readingTranslationPeek, isFalse);
    expect(find.byKey(WidgetKeys.peekCard), findsNothing);
  });

  const skip = !FeatureFlags.indopakScript; // feature shipped dark

  testWidgets(
    'settings uses compact script rows',
    (tester) async {
      await pump(tester);
      await openPanel(tester);

      final uthmaniCard =
          tester.getSize(find.byKey(WidgetKeys.scriptCard('uthmani')));
      final indopakCard =
          tester.getSize(find.byKey(WidgetKeys.scriptCard('indopak')));
      expect(uthmaniCard.height, lessThan(92));
      expect(indopakCard.height, lessThan(92));
    },
    skip: skip,
  );

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
        // Back to the reader, then swipe RIGHT (RTL → next surah).
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(MushafView),
          const Offset(400, 0),
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

  group('Reset reading preferences', () {
    testWidgets('confirming Reset restores font size, pops back, and confirms',
        (tester) async {
      await pump(tester);
      await openPanel(tester);
      await tester.tap(find.byKey(WidgetKeys.fontIncrease));
      await tester.pumpAndSettle();
      expect(readerFontSize(tester), 30);

      await tester.ensureVisible(find.byKey(WidgetKeys.readerSettingsReset));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.readerSettingsReset));
      await tester.pumpAndSettle();
      expect(find.text('Reset reading preferences?'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Back on the reader — the settings page is gone, defaults restored.
      expect(find.byKey(WidgetKeys.readerSettingsPage), findsNothing);
      expect(settings.resetCalls, 1);
      expect(settings.fontSize, 28);
      expect(readerFontSize(tester), 28);
      expect(find.text('Reading preferences reset.'), findsOneWidget);
    });

    testWidgets(
        'cancelling Reset leaves the panel open and the font size untouched',
        (tester) async {
      await pump(tester);
      await openPanel(tester);
      await tester.tap(find.byKey(WidgetKeys.fontIncrease));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(WidgetKeys.readerSettingsReset));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.readerSettingsReset));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.readerSettingsPage), findsOneWidget);
      expect(settings.resetCalls, 0);
      expect(settings.fontSize, 30);
    });
  });
}
