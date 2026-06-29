import 'dart:async';

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

// A fake player that records stop() calls and lets the test push playback states
// onto the stream the AyahAudioCubit listens to.
class _RecordingPlayer implements AyahRecitationPlayer {
  final controller = StreamController<RecitationPlayback>.broadcast();
  int stopCalls = 0;
  int? lastPlayed;

  @override
  Stream<RecitationPlayback> get playbackStream => controller.stream;

  @override
  Future<void> play(int ayahId) async {
    lastPlayed = ayahId;
    controller.add(
      RecitationPlayback(ayahId: ayahId, status: RecitationStatus.playing),
    );
  }

  /// Signal that [ayahId] finished on its own — drives continuous auto-advance.
  void complete(int ayahId) => controller.add(
        RecitationPlayback(ayahId: ayahId, status: RecitationStatus.completed),
      );

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    if (!controller.isClosed) {
      controller.add(const RecitationPlayback());
    }
  }

  @override
  Future<void> dispose() async {}
}

class _Repo implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final s = target.value;
    return [
      for (var n = 1; n <= 5; n++)
        Ayah(
          id: s * 1000 + n,
          surahId: s,
          ayahNumber: n,
          textArabic: 'نص $n',
          isSajda: false,
        ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var s = 1; s <= 114; s++)
          s: SurahHeading(number: s, nameEnglish: 'Surah $s', totalAyahs: 5),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeLastRead implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

class _FakeSettings implements ReaderSettingsRepository {
  @override
  double fontSize = 24;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations = const [];
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

void main() {
  late _RecordingPlayer player;

  setUp(() {
    player = _RecordingPlayer();
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_Repo(), _FakeLastRead()),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(player));
  });
  tearDown(GetIt.I.reset);

  Future<void> openAndPlay(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(target: ReaderTarget.surah(2, 'Al-Baqarah')),
      ),
    );
    await tester.pumpAndSettle();
    // A verse is now playing.
    player.controller.add(
      const RecitationPlayback(ayahId: 2003, status: RecitationStatus.playing),
    );
    await tester.pump();
  }

  testWidgets('swiping to another surah stops the recitation', (tester) async {
    await openAndPlay(tester);
    final before = player.stopCalls;

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(
      player.stopCalls,
      greaterThan(before),
      reason: 'recitation should stop when you swipe to another section',
    );
    // (Stopping on *leaving* the reader is covered by ayah_audio_cubit_test's
    // "close stops playback" — the per-screen cubit calls player.stop() on close.)
  });

  testWidgets(
      'a finished verse auto-advances to the next (reader fed the order)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(target: ReaderTarget.surah(2, 'Al-Baqarah')),
      ),
    );
    await tester.pumpAndSettle(); // load → the reader pushes the verse order

    // Verse 2001 is playing; let it finish → it should roll into 2002, then 2003.
    player.controller.add(
      const RecitationPlayback(ayahId: 2001, status: RecitationStatus.playing),
    );
    await tester.pump();

    player.complete(2001);
    await tester.pumpAndSettle();
    expect(
      player.lastPlayed,
      2002,
      reason: 'should continue to the next verse',
    );

    player.complete(2002);
    await tester.pumpAndSettle();
    expect(player.lastPlayed, 2003);
  });

  testWidgets('the last verse stops — no advance past the surah end',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(target: ReaderTarget.surah(2, 'Al-Baqarah')),
      ),
    );
    await tester.pumpAndSettle();

    // The fake surah has 5 verses (2001..2005); finishing the last one must NOT
    // start anything new.
    player.complete(2005);
    await tester.pumpAndSettle();
    expect(
      player.lastPlayed,
      isNull,
      reason: 'nothing plays after the last verse',
    );
  });
}
