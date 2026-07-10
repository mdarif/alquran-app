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

/// Serves a fixed ayah list (with real page numbers) — for the Kahf tall-page repro.
class _StaticRepo implements AyahRepository {
  _StaticRepo(this.ayahs);
  final List<Ayah> ayahs;
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => ayahs;
  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var s = 1; s <= 114; s++)
          s: SurahHeading(number: s, nameEnglish: 'Surah $s', totalAyahs: 20),
      };
  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
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
/// listens to, and it records stop()/pause() calls + auto-advance plays (so we can
/// prove a viewport toggle never interrupts playback the way a section swipe does,
/// and that backgrounding pauses).
class _RecordingPlayer implements AyahRecitationPlayer {
  final controller = StreamController<RecitationPlayback>.broadcast();
  int stopCalls = 0;
  int pauseCalls = 0;
  int? lastPlayed;
  int? _current; // the loaded verse, so pause() can echo `paused` for it

  @override
  Stream<RecitationPlayback> get playbackStream => controller.stream;

  /// Simulate the reciter reaching [ayahId] and sounding.
  void playing(int ayahId) {
    _current = ayahId;
    controller.add(
      RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
    );
  }

  /// Simulate [ayahId] pausing (still the active verse, just not sounding).
  void paused(int ayahId) {
    _current = ayahId;
    controller.add(
      RecitationPlayback(ayahId: ayahId, status: RecitationStatus.paused),
    );
  }

  /// Simulate [ayahId] finishing on its own — drives continuous auto-advance.
  void complete(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.completed),
      );

  @override
  Future<void> play(int ayahId) async {
    _current = ayahId;
    lastPlayed = ayahId;
    controller.add(
      RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
    );
  }

  @override
  Future<void> prefetch(int ayahId) async {}

  @override
  Future<void> pause() async {
    pauseCalls++;
    // Mirror the real player: pausing echoes `paused` for the current verse.
    final id = _current;
    if (id != null) {
      controller.add(
        RecitationPlayback(ayahId: id, status: RecitationStatus.paused),
      );
    }
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    _current = null;
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
  // verse is deliberately NOT the page's first verse. A section swipe never
  // reaches 2030, so any Last Read of exactly 2030 can only have come from
  // following the reciter — which now happens PER VERSE in BOTH views: Reading
  // splits the page-chunk at the playing verse and pins it as Last Read, so its
  // tracked position is the exact verse sounding, not a trailing page top.
  const surah = ReaderTarget.surah(2, 'Al-Baqarah');
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

  // Owner-reported (Al-Kahf): resumed to v10, then played v15 via audio selection
  // — the screen stayed on v10 instead of scrolling to v15. Al-Kahf page 294 holds
  // verses 5–15 (a tall chunk), and resuming to v10 SPLITS it at v10, so the v10–15
  // chunk's TOP is v10. If the follow can't resolve v15's position inside that tall
  // chunk it falls back to the chunk top (= v10) — the bug. This plays v15 in that
  // exact state and asserts the follow scrolls PAST v10 to v15.
  testWidgets('Kahf: playing a verse deep in a tall (split) page scrolls to IT',
      (tester) async {
    // Real Al-Kahf char lengths for verses 5–15 (from quran.db) so page 294's
    // geometry matches the device: variable lengths, a chunk several viewports tall.
    const realLen = {
      5: 127,
      6: 100,
      7: 93,
      8: 52,
      9: 86,
      10: 129,
      11: 62,
      12: 84,
      13: 108,
      14: 167,
      15: 167,
      16: 172,
      17: 275,
      18: 227,
      19: 375,
      20: 117,
    };
    String verse(int n) =>
        List.filled(((realLen[n] ?? 40) / 6).ceil(), 'كلمة').join(' ');
    final ayahs = [
      for (var n = 1; n <= 20; n++)
        Ayah(
          id: 18000 + n,
          surahId: 18,
          ayahNumber: n,
          textArabic: n <= 4 ? 'نص قصير $n' : verse(n),
          page: n <= 4
              ? 293
              : n <= 15
                  ? 294
                  : 295,
          isSajda: false,
        ),
    ];
    GetIt.I
      ..unregister<ReaderCubit>()
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_StaticRepo(ayahs), lastRead),
      );
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          target: ReaderTarget.surah(18, 'Kahf'),
          focusAyahId: 18010, // resumed to v10 (splits page 294 at v10)
        ),
      ),
    );
    await tester.pumpAndSettle();
    final vpTop = tester.getTopLeft(find.byType(MushafView)).dy;
    final vpH = tester.getSize(find.byType(MushafView)).height;
    double markerFrac(int v) =>
        (tester.getTopLeft(find.text('$v').first).dy - vpTop) / vpH;

    // Sitting at v10, JUMP to v15 (audio selection), then advance to v16 (new page).
    for (final n in [10, 15, 16]) {
      player.playing(18000 + n);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
    // After v15→v16 the reciter is on v16 (page 295's first verse), which must be at
    // the top; the whole v10–15 chunk is above it.
    expect(find.text('16'), findsOneWidget);
    expect(
      markerFrac(16),
      inInclusiveRange(0.0, 0.6),
      reason: 'v16 must be at the top',
    );

    // The core assertion: re-play v15 (deep in the tall v10–15 chunk) — it must
    // scroll UP to v15, leaving v10 (the split chunk's top) above the viewport.
    player.playing(18015);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget, reason: 'v15 must be on screen');
    expect(
      markerFrac(15),
      inInclusiveRange(0.0, 0.6),
      reason: 'v15 must be near the top, not scrolled off',
    );
    expect(
      markerFrac(10),
      lessThan(0.0),
      reason: 'the split chunk top (v10) must be scrolled ABOVE the viewport — '
          'the follow reached v15, it did not fall back to the page top',
    );
  });

  testWidgets('reading-view keeps the reciter\'s verse near the top',
      (tester) async {
    await open(tester, detailed: false);
    final vpTop = tester.getTopLeft(find.byType(MushafView)).dy;
    final vpHeight = tester.getSize(find.byType(MushafView)).height;

    for (final n in [28, 29, 30, 31, 32, 33, 34, 35, 36]) {
      player.playing(2000 + n);
      await tester.pumpAndSettle(); // primary follow-scroll
      await tester
          .pump(const Duration(milliseconds: 500)); // fire the corrective
      await tester
          .pumpAndSettle(); // let the corrective settle (verses last seconds)
      final badge = find.text('$n');
      expect(
        badge,
        findsOneWidget,
        reason: 'verse $n is off-screen — the follow lost it (or scrolled it '
            'above the top)',
      );
      // The verse's marker sits in the upper band — verse ABOVE it starts at the
      // very top; it must never be pushed off above, nor drift down mid-screen.
      final frac = (tester.getTopLeft(badge.first).dy - vpTop) / vpHeight;
      expect(
        frac,
        inInclusiveRange(0.0, 0.4),
        reason: 'verse $n marker at ${frac.toStringAsFixed(2)} of the viewport '
            '— must stay near the top',
      );
    }
  });

  group('moving viewports while a verse is reciting', () {
    testWidgets(
        'Reading → Detailed lands on the reciter\'s verse, not the page top',
        (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);

      // Reading now follows the reciter PER VERSE: the page-chunk splits at the
      // playing verse and that verse is pinned as Last Read, so the outgoing
      // view already tracks the exact verse sounding — no trailing page top.
      expect(
        lastRead.saved?.ayahId,
        recitingVerse,
        reason:
            'Reading tracks the reciting verse per-verse (chunk split + pin)',
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
      expect(
        player.stopCalls,
        stopsBefore,
        reason: 'toggle must not stop audio',
      );
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

  // A PAUSED verse is still the reader's current verse: pausing to switch views
  // and see/read that exact verse is a core listener flow (owner-reported — pause
  // 7:10 in Detailed, switch to Reading, and it must land on 7:10, not 7:9). So a
  // switch homes to the paused verse in BOTH directions, exactly as while it plays.
  group('moving viewports with a paused verse', () {
    testWidgets('Detailed → Reading lands on the paused verse (not one before)',
        (tester) async {
      await open(tester, detailed: true);
      await startReciting(tester, recitingVerse);
      player.paused(recitingVerse);
      await tester.pumpAndSettle();

      await toggleViewport(tester);

      expect(find.byType(MushafView), findsOneWidget, reason: 'now in Reading');
      expect(
        lastRead.saved?.ayahId,
        recitingVerse,
        reason:
            'a paused verse stays the reading position — Detailed follows it '
            'a verse-sliver early, so the flush alone would hand Reading the '
            'verse just above it (the reported 7:10 → 7:9 slip)',
      );
    });

    testWidgets('Reading → Detailed lands on the paused verse', (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);
      player.paused(recitingVerse);
      await tester.pumpAndSettle();

      await toggleViewport(tester);

      expect(find.byType(MushafView), findsNothing, reason: 'now in Detailed');
      expect(lastRead.saved?.ayahId, recitingVerse);
    });
  });

  testWidgets(
      'stopped, then scrolled away, homes to the reading position (not the '
      'verse that was playing)', (tester) async {
    // The force-home override is bounded to when a verse is actually loaded in
    // the player. Once audio fully stops (idle — end of surah, or a section swipe
    // stops it) there is no "current verse": the reciter pin releases and a switch
    // homes to wherever the reader has since scrolled, NOT the last verse played.
    // (Per-verse follow scrolls the heard verse to the top, so at the stop point
    // the reading position IS 2030 — we scroll away first to tell the two apart.)
    await open(tester, detailed: false);
    await startReciting(tester, recitingVerse);
    player.controller.add(const RecitationPlayback()); // idle: no current verse
    await tester.pumpAndSettle();

    // Scroll back up, away from verse 2030 (a plain vertical drag).
    await tester.drag(find.byType(MushafView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500)); // settle + report

    await toggleViewport(tester);

    expect(
      lastRead.saved?.ayahId,
      isNot(recitingVerse),
      reason: 'stopped → not force-homed to the verse that WAS playing',
    );
    expect(
      lastRead.saved?.ayahId,
      lessThan(recitingVerse),
      reason: 'stopped → homes to the scrolled-to reading position',
    );
  });

  // Recitation is foreground-only (no background audio service), so leaving the
  // foreground must pause — otherwise the reader returns showing "playing" over
  // silence. The reader owns this: audio can only sound while a reader is open.
  group('app backgrounded during recitation', () {
    // Drive the valid resumed → inactive → paused transition (the handler acts
    // only on paused/hidden).
    Future<void> background(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
    }

    testWidgets('a playing verse pauses when the app backgrounds',
        (tester) async {
      await open(tester, detailed: false);
      await startReciting(tester, recitingVerse);
      expect(player.pauseCalls, 0);

      await background(tester);

      expect(
        player.pauseCalls,
        1,
        reason: 'foreground-only: a sounding verse must pause on background',
      );
    });

    testWidgets('backgrounding with nothing playing is a no-op',
        (tester) async {
      await open(tester, detailed: false);
      // No recitation started — nothing is loaded in the player.
      await background(tester);

      expect(
        player.pauseCalls,
        0,
        reason: 'no current verse → nothing to pause (and no player woken)',
      );
    });
  });
}
