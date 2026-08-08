import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/audio/translation_audio_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/entities/installed_edition.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:al_quran/features/translations/presentation/cubit/translations_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// A no-op recorder — these tests only care whether the per-verse translation-
/// audio (headphones) affordance renders, not what it does once tapped.
class _NoopPlayer implements AyahRecitationPlayer {
  final controller = StreamController<RecitationPlayback>.broadcast();

  @override
  Stream<RecitationPlayback> get playbackStream => controller.stream;
  @override
  Future<void> play(int ayahId) async {}
  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
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
  Future<void> dispose() async {}
}

/// Drivable Arabic player — lets a test push playback events directly, the
/// same pattern as `reader_audio_nav_test.dart`'s `_RecordingPlayer`.
class _DrivablePlayer implements AyahRecitationPlayer {
  final controller = StreamController<RecitationPlayback>.broadcast();

  void playing(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
      );
  void complete(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.completed),
      );

  @override
  Stream<RecitationPlayback> get playbackStream => controller.stream;
  @override
  Future<void> play(int ayahId) async {}
  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
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
  Future<void> dispose() async {}
}

/// Records translation-audio playback requests — a regression test can assert
/// on [calls] to prove the chain did/didn't fire after a translation swap.
class _RecordingTranslationPlayer implements TranslationAudioPlayer {
  final List<String> calls = [];
  Completer<void>? _pending;

  @override
  Future<void> play({required int surah, required int ayah}) {
    calls.add('play(surah: $surah, ayah: $ayah)');
    _pending = Completer<void>();
    return _pending!.future;
  }

  void completeCurrent() => _pending?.complete();

  @override
  Future<void> stop() async {}
}

/// Two already-installed, audio-relevant editions (no catalogue/download
/// needed) — enough for the Translations sheet to show both as toggleable
/// rows.
class _EditionRepo implements EditionRepository {
  @override
  Future<EditionCatalogue> catalogue() async =>
      const EditionCatalogue(editions: []);
  @override
  Future<List<InstalledEdition>> installed() async => [
        InstalledEdition(
          slug: 'en-sahih-international',
          type: 'translation',
          languageCode: 'en',
          name: 'Sahih International',
          bytes: 100,
          installedAt: DateTime(2026),
        ),
        InstalledEdition(
          slug: 'ur-junagarhi',
          type: 'translation',
          languageCode: 'ur',
          name: 'Urdu',
          bytes: 100,
          installedAt: DateTime(2026),
        ),
      ];
  @override
  Future<void> install(
    CatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}
  @override
  Future<void> remove(String slug) async {}
}

/// Al-Fatihah's 7 ayahs (surah 1) — a small, convenient fixture surah.
class _FatihaRepo implements AyahRepository {
  _FatihaRepo(this.resources);
  final List<TranslationResource> resources;

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => [
        for (var n = 1; n <= 7; n++)
          Ayah(
            id: n,
            surahId: 1,
            ayahNumber: n,
            textArabic: 'نص $n',
            isSajda: false,
          ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        1: const SurahHeading(
          number: 1,
          nameEnglish: 'Al-Fatihah',
          totalAyahs: 7,
        ),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async =>
      resources;
}

class _FakeLastRead implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null;
}

class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({this.selectedTranslations = const []});

  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
  @override
  double fontSize = 24;
  @override
  bool detailed = true; // the toggle only ever renders in Detailed mode
  @override
  List<String>? selectedTranslations;
  @override
  ArabicScript script = ArabicScript.uthmani;
  @override
  Future<void> setScript(ArabicScript value) async => script = value;
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
  @override
  Future<void> resetToDefaults() async {}
}

const _sahih = TranslationResource(
  id: 1,
  slug: 'en-sahih-international',
  languageCode: 'en',
  name: 'Sahih International',
);
const _urdu = TranslationResource(
  id: 2,
  slug: 'ur-junagarhi',
  languageCode: 'ur',
  name: 'Urdu',
  direction: 'rtl',
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<TranslationResource> resources,
  ) async {
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_FatihaRepo(resources), _FakeLastRead()),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new)
      ..registerFactory<AyahAudioCubit>(
        () =>
            AyahAudioCubit(_NoopPlayer(), GetIt.I<ReaderSettingsRepository>()),
      );
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          target: ReaderTarget.surah(1, 'Al-Fatihah'),
          initialDetailed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(GetIt.I.reset);

  testWidgets(
      'headphones affordance shows on Fatiha verses when Sahih International is shown',
      (tester) async {
    await pump(tester, const [_sahih, _urdu]);
    expect(
      find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)),
      findsOneWidget,
    );
  });

  testWidgets(
      'headphones affordance is hidden when no shown translation has audio',
      (tester) async {
    await pump(tester, const [_urdu]); // no audio-backed edition shown
    expect(find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)), findsNothing);
  });

  group('swapping the audio-backed translation out (regression)', () {
    testWidgets(
        'turns translation audio OFF and stops chaining once Sahih International '
        'is deselected in favour of a different translation', (tester) async {
      final player = _DrivablePlayer();
      final translationPlayer = _RecordingTranslationPlayer();
      final settings = _FakeSettings(
        selectedTranslations: ['en-sahih-international'],
      );
      GetIt.I
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(
            _FatihaRepo(const [_sahih, _urdu]),
            _FakeLastRead(),
          ),
        )
        ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
        ..registerFactory<AyahAudioCubit>(
          () => AyahAudioCubit(player, settings, translationPlayer),
        )
        ..registerLazySingleton<EditionRepository>(_EditionRepo.new)
        ..registerLazySingleton<TranslationsCubit>(
          () => TranslationsCubit(
            GetIt.I<EditionRepository>(),
            const [],
            settings: settings,
          ),
        );

      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(1, 'Al-Fatihah'),
            initialDetailed: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sahih International is shown → the headphones icon is there; turn it on.
      expect(
        find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)));
      await tester.pump();

      // Play ayah 1 to completion — the translation clip must chain in.
      player.playing(1);
      await tester.pump();
      player.complete(1);
      await tester.pump();
      expect(translationPlayer.calls, isNotEmpty);
      translationPlayer.completeCurrent();
      await tester.pumpAndSettle();

      // Open Translations, select Urdu, then deselect Sahih International —
      // "removed the audio-backed translation, added a different one".
      await tester.tap(find.byKey(WidgetKeys.settingsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Translations'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.editionRow('ur-junagarhi')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(WidgetKeys.editionRow('en-sahih-international')));
      await tester.pumpAndSettle();

      expect(settings.selectedTranslations, ['ur-junagarhi']);

      // Back in the reader: the headphones icon must be gone...
      await tester.tapAt(const Offset(20, 20)); // dismiss the sheet
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20)); // dismiss Settings too
      await tester.pumpAndSettle();
      expect(
        find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)),
        findsNothing,
      );

      // ...and playing ayah 1 again must NOT chain in Sahih's audio anymore —
      // this is the regression: the toggle used to stay silently ON.
      translationPlayer.calls.clear();
      player.playing(1);
      await tester.pump();
      player.complete(1);
      await tester.pumpAndSettle();
      expect(translationPlayer.calls, isEmpty);
    });
  });

  group('switching to Reading mode (regression)', () {
    testWidgets(
        'turns translation audio OFF when leaving Detailed — translation '
        'audio is Detailed-only (plan decision #1)', (tester) async {
      final player = _DrivablePlayer();
      final translationPlayer = _RecordingTranslationPlayer();
      final settings = _FakeSettings(
        selectedTranslations: ['en-sahih-international'],
      );
      GetIt.I
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(
            _FatihaRepo(const [_sahih, _urdu]),
            _FakeLastRead(),
          ),
        )
        ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
        ..registerFactory<AyahAudioCubit>(
          () => AyahAudioCubit(player, settings, translationPlayer),
        );

      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(1, 'Al-Fatihah'),
            initialDetailed: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Turn translation audio on in Detailed and prove it chains.
      await tester.tap(find.byKey(WidgetKeys.ayahTranslationAudioToggle(1)));
      await tester.pump();
      player.playing(1);
      await tester.pump();
      player.complete(1);
      await tester.pump();
      expect(translationPlayer.calls, isNotEmpty);
      translationPlayer.completeCurrent();
      await tester.pumpAndSettle();

      // Switch to Reading — no headphones affordance exists there to turn it
      // off manually, so the reader must do it automatically.
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();

      // Playing a verse in Reading must NOT chain in translation audio — this
      // is the regression: the flag used to survive the viewport switch with
      // no way left to turn it off.
      translationPlayer.calls.clear();
      player.playing(1);
      await tester.pump();
      player.complete(1);
      await tester.pumpAndSettle();
      expect(translationPlayer.calls, isEmpty);

      // Switching back to Detailed confirms the toggle reset, not just muted:
      // the headphones icon is off (not merely hidden) and must be tapped
      // again to re-enable chaining.
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();
      player.playing(1);
      await tester.pump();
      player.complete(1);
      await tester.pumpAndSettle();
      expect(translationPlayer.calls, isEmpty);
    });
  });
}
