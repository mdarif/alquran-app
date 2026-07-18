import 'package:al_quran/core/audio/ayah_recitation_player.dart';
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

// Every surah is a long 60-verse chapter with translations, so the reader
// genuinely scrolls and a pinch can drift the position; multiple surahs exist so
// a stray swipe during a pinch would be detectable.
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
          // 8 verses per Mushaf page → the Reading view chunks into several lazy
          // paragraphs, as it does against the real page-numbered DB.
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
}

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

/// Spreads two fingers apart on the reader body — a pinch-OUT that enlarges the
/// Arabic font through the raw Listener (the real zoom path), then lifts both.
Future<void> _pinchOut(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(PageView));
  final f1 = await tester.startGesture(center + const Offset(-24, 0));
  final f2 = await tester.startGesture(center + const Offset(24, 0));
  for (var i = 0; i < 14; i++) {
    await f1.moveBy(const Offset(-14, 0));
    await f2.moveBy(const Offset(14, 0));
    await tester.pump();
  }
  await f1.up();
  await f2.up();
  await tester.pump();
}

void main() {
  late _RecordingLastRead lastRead;
  late _FakeSettings settings;

  setUp(() {
    lastRead = _RecordingLastRead();
    settings = _FakeSettings();
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_LongSurahRepo(), lastRead),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(() => settings)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));
  });
  tearDown(GetIt.I.reset);

  // Open surah 2 already scrolled to [ayahNumber] via focusAyahId (the index
  // scroll controller is reliable in tests, unlike a synthetic drag).
  Future<void> openAt(
    WidgetTester tester, {
    required bool detailed,
    required int ayahNumber,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          target: const ReaderTarget.surah(2, 'Al-Baqarah'),
          focusAyahId: 2000 + ayahNumber,
          initialDetailed: detailed,
        ),
      ),
    );
    await tester.pumpAndSettle(); // load + scroll-to-focus animation
    await tester.pump(const Duration(milliseconds: 500)); // debounced report
  }

  // The reading position must survive a pinch-zoom in BOTH viewports: the larger
  // text must not push Last Read back to an earlier verse.
  for (final detailed in const [false, true]) {
    final view = detailed ? 'Detailed' : 'Reading';
    testWidgets('$view view: pinch-zoom keeps the Last Read verse',
        (tester) async {
      await openAt(tester, detailed: detailed, ayahNumber: 25);
      final before = lastRead.saved?.ayahNumber ?? 0;
      expect(before, greaterThan(8), reason: 'opened scrolled into the surah');

      await _pinchOut(tester);
      await tester.pump(const Duration(milliseconds: 500));

      // The pinch must really have enlarged the font, else the test is vacuous.
      expect(
        settings.fontSize,
        greaterThanOrEqualTo(40),
        reason: 'pinch should have enlarged the font well past the 22 start',
      );
      final after = lastRead.saved?.ayahNumber ?? 0;
      expect(
        after,
        greaterThanOrEqualTo(before - 2),
        reason: '$view pinch drifted Last Read from $before to $after',
      );
    });
  }

  testWidgets('a two-finger pinch never doubles as a surah swipe',
      (tester) async {
    await openAt(tester, detailed: false, ayahNumber: 5);
    expect(find.text('Al-Baqarah'), findsOneWidget); // app-bar title, surah 2

    await _pinchOut(tester);
    await tester.pumpAndSettle();

    // Still surah 2 — the PageView was locked while two fingers were down.
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Surah 1'), findsNothing);
    expect(find.text('Surah 3'), findsNothing);
  });

  testWidgets('viewport toggle after a zoom keeps your place', (tester) async {
    await openAt(tester, detailed: false, ayahNumber: 25);
    expect(find.byType(MushafView), findsOneWidget); // Reading
    final before = lastRead.saved?.ayahNumber ?? 0;
    expect(before, greaterThan(8));

    // Zoom in, then switch Reading -> Detailed: _setDetailed flushes the live
    // verse so the incoming viewport homes to it (a zoom must not corrupt that).
    await _pinchOut(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Detailed view'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MushafView), findsNothing); // now Detailed
    expect(lastRead.saved?.detailed, isTrue);
    // Your place is kept: Detailed homes to the same verse (a few earlier at the
    // very top is just its focus-alignment showing some context above it) — it
    // must not reset to the top, nor jump forward past where you were.
    final after = lastRead.saved?.ayahNumber ?? 0;
    expect(
      after,
      greaterThan(10),
      reason: 'toggle reset to the top (was $before, now $after)',
    );
    expect(
      after,
      lessThanOrEqualTo(before + 2),
      reason: 'toggle jumped forward (was $before, now $after)',
    );
  });

  testWidgets('swiping to the next surah records Last Read for that surah',
      (tester) async {
    await openAt(tester, detailed: false, ayahNumber: 1);
    expect(lastRead.saved?.surahId, 2); // started on surah 2

    // Swipe RIGHT → next surah (RTL/Mushaf paging).
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1200);
    await tester.pumpAndSettle();

    // Last Read now points at the new section, opened at its first verse.
    expect(lastRead.saved?.surahId, 3);
    expect(lastRead.saved?.ayahNumber, 1);
    expect(lastRead.saved?.target.value, 3);
  });

  // Resume must land EXACTLY on the saved verse — not the verse that happens to
  // end up at the top after the scroll (which, deep in a surah where the scroll
  // can't reach the usual offset, drifted by many verses before the pin fix).
  for (final detailed in const [false, true]) {
    final view = detailed ? 'Detailed' : 'Reading';
    for (final n in const [15, 50]) {
      testWidgets('$view: resumes exactly at verse $n (no drift)',
          (tester) async {
        await openAt(tester, detailed: detailed, ayahNumber: n);
        expect(
          lastRead.saved?.ayahNumber,
          n,
          reason: '$view resume drifted off verse $n',
        );
      });
    }
  }

  testWidgets('a finger scroll after resume releases the pin (tracks the top)',
      (tester) async {
    await openAt(tester, detailed: false, ayahNumber: 50);
    expect(lastRead.saved?.ayahNumber, 50); // pinned to the resume verse

    // A real finger drag DOWN reveals earlier verses; it must unpin Last Read so
    // it follows the new top instead of staying frozen on verse 50.
    await tester.drag(find.byType(MushafView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1300));

    expect(
      lastRead.saved?.ayahNumber,
      lessThan(50),
      reason: 'after scrolling, Last Read should track the top, not the pin',
    );
  });
}
