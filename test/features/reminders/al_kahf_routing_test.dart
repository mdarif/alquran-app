import 'package:al_quran/app_navigator.dart';
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
import 'package:al_quran/features/reminders/domain/scheduling/reminder_payload.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// Al-Kahf-shaped stub: 110 verses, one surah is enough for this routing test.
class _Repo implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => [
        for (var n = 1; n <= 110; n++)
          Ayah(
            id: target.value * 1000 + n,
            surahId: target.value,
            ayahNumber: n,
            textArabic: 'نص $n',
            page: 293 + (n - 1) ~/ 8,
            isSajda: false,
          ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var s = 1; s <= 114; s++)
          s: SurahHeading(number: s, nameEnglish: 'Surah $s', totalAyahs: 110),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeLastRead implements LastReadRepository {
  _FakeLastRead(this.saved);
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

class _FakeSettings implements ReaderSettingsRepository {
  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
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
  @override
  bool translationAudioDuringContinuousPlayback = true;
  @override
  Future<void> setTranslationAudioDuringContinuousPlayback(bool value) async =>
      translationAudioDuringContinuousPlayback = value;
  @override
  Future<void> resetToDefaults() async {}
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

LastRead _lr(int surahId, int ayahNumber, {bool detailed = false}) => LastRead(
      target: ReaderTarget.surah(surahId, 'Surah $surahId'),
      ayahId: surahId * 1000 + ayahNumber,
      surahId: surahId,
      ayahNumber: ayahNumber,
      detailed: detailed,
    );

void main() {
  setUp(() {
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_Repo(), _FakeLastRead(null)),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));
  });
  tearDown(GetIt.I.reset);

  Future<ReaderPage?> route(WidgetTester tester, LastRead? lastRead) async {
    GetIt.I.registerLazySingleton<LastReadRepository>(
      () => _FakeLastRead(lastRead),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    await routeFromPayload(openAlKahfPayload);
    await tester.pumpAndSettle();
    final found = find.byType(ReaderPage);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<ReaderPage>(found.first);
  }

  testWidgets('the Al-Kahf reminder resumes where Al-Kahf was left off',
      (tester) async {
    final page = await route(tester, _lr(18, 60, detailed: true));

    expect(page, isNotNull);
    expect(page!.target, const ReaderTarget.surah(18, 'Surah 18'));
    expect(page.focusAyahId, 18060); // ayah 60, not the top
    expect(page.initialDetailed, isTrue);
  });

  testWidgets('a resume point elsewhere still opens Al-Kahf from the top',
      (tester) async {
    final page = await route(tester, _lr(2, 255));

    expect(page, isNotNull);
    expect(page!.target, const ReaderTarget.surah(18, 'Al-Kahf'));
    expect(page.focusAyahId, isNull);
  });

  testWidgets('nothing read yet: opens Al-Kahf from the top', (tester) async {
    final page = await route(tester, null);

    expect(page, isNotNull);
    expect(page!.target, const ReaderTarget.surah(18, 'Al-Kahf'));
    expect(page.focusAyahId, isNull);
  });
}
