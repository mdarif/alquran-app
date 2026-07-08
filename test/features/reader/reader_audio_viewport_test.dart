import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_icons.dart';
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
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// The listener's core experience: play a verse in one viewport, then move to the
// other viewport WITHOUT losing the reciter. These tests pin the behaviour the
// owner flagged — switching Reading⇄Detailed mid-recitation must land on the
// verse actually being recited, not on wherever the outgoing view was scrolled.
//
// Surah 2 here is a 60-verse chapter chunked 8 verses per Mushaf page (mirroring
// the real page-numbered DB), so the Reading view follows the reciter a whole
// PAGE at a time — which is exactly what made the page's first verse (not the
// reciter's verse) leak across a viewport switch before the fix.
class _LongSurahRepo implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final s = target.value;
    return [
      for (var n = 1; n <= 60; n++)
        Ayah(
          id: s * 1000 + n,
          surahId: s,
          ayahNumber: n,
          textArabic: 'نص الآية رقم $n',
          // 8 verses per Mushaf page → several lazy paragraphs per section.
          page: s * 100 + (n - 1) ~/ 8,
          isSajda: false,
          translations: {1: 'اردو ترجمہ $n', 2: 'हिंदी अनुवाद $n'},
        ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var s = 1; s <= 114; s++)
          s: SurahHeading(number: s, nameEnglish: 'Surah $s', totalAyahs: 60),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [
        TranslationResource(id: 1, languageCode: 'ur', name: 'Urdu'),
        TranslationResource(id: 2, languageCode: 'hi', name: 'Hindi'),
      ];
}

class _RecordingLastRead implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

class _FakeSettings implements ReaderSettingsRepository {
  @override
  double fontSize = 22;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations = const ['ur', 'hi'];
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
  bool readingTranslationVisible = true;
  @override
  Future<void> setReadingTranslationVisible(bool value) async =>
      readingTranslationVisible = value;
}

/// A fake player: the test pushes playback states onto the stream the cubit
/// listens to, and it records stop() calls + auto-advance plays (so we can prove
/// a viewport toggle never interrupts playback the way a section swipe does).
class _RecordingPlayer implements AyahRecitationPlayer {
  final controller = StreamController<RecitationPlayback>.broadcast();
  int stopCalls = 0;
  int? lastPlayed;

  @override
  Stream<RecitationPlayback> get playbackStream => controller.stream;

  /// Simulate the reciter reaching [ayahId] and sounding.
  void playing(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
      );

  /// Simulate [ayahId] pausing (still the active verse, just not sounding).
  void paused(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.paused),
      );

  /// Simulate [ayahId] finishing on its own — drives continuous auto-advance.
  void complete(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.completed),
      );

  @override
  Future<void> play(int ayahId) async {
    lastPlayed = ayahId;
    controller.add(
      RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
    );
  }

  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    if (!controller.isClosed) controller.add(const RecitationPlayback());
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late _RecordingLastRead lastRead;
  late _RecordingPlayer player;

  setUp(() {
    lastRead = _RecordingLastRead();
    player = _RecordingPlayer();
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_LongSurahRepo(), lastRead),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(player));
  });
  tearDown(GetIt.I.reset);

  // Verse 2030 sits MID-page (page 203 spans verses 25–32), so the reciter's
  // verse is deliberately NOT the page's first verse — the discrepancy the bug
  // rode on. A section swipe never reaches 2030, so any Last Read of exactly
  // 2030 can only have come from homing to the reciter. (Both views actually
  // track a verse a little BEHIND the reciter while following — the focus verse
  // sits a sliver below the top, leaving the previous verse/page peeking above —
  // which is precisely why an imprecise hand-off across viewports lands wrong.)
  const surah = ReaderTarget.surah(2, 'Al-Baqarah');
  const firstVerse = 2001;
  const recitingVerse = 2030;

  Finder pauseIn(Finder button) =>
      find.descendant(of: button, matching: find.byIcon(AppIcons.pause));

  /// Open the reader in [detailed] view and let the section load + settle.
  Future<void> open(WidgetTester tester, {required bool detailed}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(target: surah, initialDetailed: detailed),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Start [ayahId] sounding and let the active viewport follow it (its scroll
  /// animation + the debounced Last Read report both flush).
  Future<void> startReciting(WidgetTester tester, int ayahId) async {
    player.playing(ayahId);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> toggleViewport(WidgetTester tester) async {
    await tester.tap(find.byKey(WidgetKeys.viewportToggle));
    await tester.pumpAndSettle();
    await tester
        .pump(const Duration(milliseconds: 500)); // home scroll + report
  }

  group('moving viewports while a verse is reciting', () {
    testWidgets(
        'Reading → Detailed lands on the reciter\'s verse, not the page top',
        (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);

      // Reading follows the reciter only a whole Mushaf page at a time, so the
      // outgoing view's tracked position trails BEHIND the mid-page reciter — it
      // is emphatically not the verse sounding. That gap is the whole bug.
      expect(
        lastRead.saved?.ayahId,
        lessThan(recitingVerse),
        reason:
            'Reading tracks the page top, which trails the mid-page reciter',
      );

      await toggleViewport(tester);

      // The reported bug: Detailed opened on the trailing page top (~2017) and
      // only caught up when the verse finished. It must home to the reciter (2030).
      expect(find.byType(MushafView), findsNothing, reason: 'now in Detailed');
      expect(lastRead.saved?.detailed, isTrue);
      expect(
        lastRead.saved?.ayahId,
        recitingVerse,
        reason: 'Detailed must home to the verse being recited, not the page '
            'top it inherited from Reading',
      );
      // And the reciter\'s tile is the live one (its pause control is showing).
      expect(
        pauseIn(find.byKey(WidgetKeys.ayahPlayButton(recitingVerse))),
        findsOneWidget,
      );
    });

    testWidgets('Detailed → Reading keeps the reciter\'s verse',
        (tester) async {
      await open(tester, detailed: true);
      await startReciting(tester, recitingVerse);
      // Detailed follows per-verse: the reciter's tile is the live one on screen.
      expect(
        pauseIn(find.byKey(WidgetKeys.ayahPlayButton(recitingVerse))),
        findsOneWidget,
      );

      await toggleViewport(tester);

      expect(find.byType(MushafView), findsOneWidget, reason: 'now in Reading');
      expect(lastRead.saved?.detailed, isFalse);
      expect(
        lastRead.saved?.ayahId,
        recitingVerse,
        reason: 'Reading must open on the reciter\'s verse',
      );
    });

    testWidgets('toggling the viewport never interrupts playback',
        (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);
      final stopsBefore = player.stopCalls;

      // Reading → Detailed → Reading: unlike a section swipe (which stops the
      // reciter), a viewport toggle must leave playback running throughout.
      await toggleViewport(tester);
      expect(player.stopCalls, stopsBefore,
          reason: 'toggle must not stop audio');
      expect(
        pauseIn(find.byKey(WidgetKeys.ayahPlayButton(recitingVerse))),
        findsOneWidget,
        reason: 'still sounding in Detailed',
      );

      await toggleViewport(tester);
      expect(player.stopCalls, stopsBefore, reason: 'still not stopped');
      expect(find.byType(MushafView), findsOneWidget);
    });

    testWidgets('continuous playback keeps following in the new viewport',
        (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);
      await toggleViewport(tester); // now in Detailed, homed to 2030

      // The verse ends on its own → the cubit rolls into the next one, and the
      // (now Detailed) viewport must follow the advance without a manual toggle.
      player.complete(recitingVerse);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(player.lastPlayed, recitingVerse + 1, reason: 'auto-advanced');
      // Detailed scrolled the next verse into view and it is now the live tile —
      // continuous "play from here" survived the viewport switch.
      expect(
        pauseIn(find.byKey(WidgetKeys.ayahPlayButton(recitingVerse + 1))),
        findsOneWidget,
        reason: 'Detailed followed the reciter into the next verse',
      );
    });
  });

  testWidgets(
      'a PAUSED reader keeps their browsing place on switch (not force-homed)',
      (tester) async {
    // Fix is scoped to a SOUNDING reciter: once paused, the reader is browsing
    // again (the now-playing tint clears, the verse stepper re-enables), so a
    // viewport switch should keep the scroll position, not snap to the verse
    // that was paused.
    await open(tester, detailed: false);
    await startReciting(tester, recitingVerse);
    player.paused(recitingVerse);
    await tester.pumpAndSettle();

    await toggleViewport(tester);

    expect(
      lastRead.saved?.ayahId,
      isNot(recitingVerse),
      reason: 'paused → do not force-home to the paused verse',
    );
    // Kept the browsing position (which trails the paused verse), rather than
    // snapping forward to it — and did not reset to the top of the surah.
    expect(
      lastRead.saved?.ayahId,
      allOf(lessThan(recitingVerse), greaterThan(firstVerse)),
      reason: 'paused → keep the place the reader was browsing',
    );
  });
}
