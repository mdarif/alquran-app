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
}
