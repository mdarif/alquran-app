import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/widgets/reader_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the bar/sheet ask of the player and lets the test push playback
/// states back onto the stream the cubit listens to.
class _RecordingPlayer implements AyahRecitationPlayer {
  final _controller = StreamController<RecitationPlayback>.broadcast();
  final _progress = StreamController<PlaybackProgress>.broadcast();
  final List<String> calls = [];
  int? lastPlayed;

  void push(int? ayahId, RecitationStatus status) {
    // Remember the last real verse so pause/resume re-emit it (just_audio keeps
    // the same source loaded across a pause — the bar must stay on that verse).
    if (ayahId != null) lastPlayed = ayahId;
    _controller.add(RecitationPlayback(ayahId: ayahId, status: status));
  }

  @override
  Stream<RecitationPlayback> get playbackStream => _controller.stream;
  @override
  Stream<PlaybackProgress> get progressStream => _progress.stream;

  @override
  Future<void> play(int ayahId) async {
    lastPlayed = ayahId;
    calls.add('play($ayahId)');
    push(ayahId, RecitationStatus.playing);
  }

  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Future<void> pause() async {
    calls.add('pause');
    push(lastPlayed, RecitationStatus.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    push(lastPlayed, RecitationStatus.playing);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (!_controller.isClosed) _controller.add(const RecitationPlayback());
  }

  @override
  Future<void> seek(Duration position) async => calls.add('seek');
  @override
  Future<void> setSpeed(double speed) async => calls.add('setSpeed($speed)');
  @override
  double get speed => 1.0;
  @override
  Future<void> setLoopMode(RecitationLoop mode) async =>
      calls.add('setLoopMode(${mode.name})');
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

void main() {
  late _RecordingPlayer player;
  late AyahAudioCubit audio;
  late ReaderCubit reader;

  setUp(() async {
    player = _RecordingPlayer();
    audio = AyahAudioCubit(player);
    reader = ReaderCubit(_Repo(), _FakeLastRead());
    await reader.load(const ReaderTarget.surah(2, 'Al-Baqarah'));
    // The reader normally teaches the cubit the on-screen order; do it here so
    // prev/next have a sequence to walk.
    audio.setSequence([2001, 2002, 2003, 2004, 2005]);
  });
  tearDown(() async {
    if (!audio.isClosed) await audio.close();
    if (!reader.isClosed) await reader.close();
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: audio),
            BlocProvider.value(value: reader),
          ],
          child: const Scaffold(bottomNavigationBar: ReaderPlayerBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Widget tests run under FakeAsync, where a single `pump()` doesn't reliably
  /// drain the chained broadcast-stream microtasks (player stream → cubit → bloc
  /// state stream → widget). Drive that hop with real async, then rebuild.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> playVerse(WidgetTester tester, int id) async {
    player.push(id, RecitationStatus.playing);
    await settle(tester);
  }

  testWidgets('always visible; idle shows play + the reciter', (tester) async {
    await pumpBar(tester);
    // Always-on: the bar is present even before anything plays, minimal (a play
    // control + the reciter name).
    expect(find.byKey(WidgetKeys.playerBar), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerBarPlay), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
  });

  testWidgets('when a verse plays, the transport controls appear',
      (tester) async {
    await pumpBar(tester);
    await playVerse(tester, 2003);

    // One slim row: repeat · prev · play/pause · next · speed. No verse label —
    // the gold-highlighted verse in the page shows which one is playing.
    expect(find.byKey(WidgetKeys.playerBar), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerRepeat), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerBarPrev), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerBarPlay), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerBarNext), findsOneWidget);
    expect(find.byKey(WidgetKeys.playerSpeed), findsOneWidget);
    expect(find.text('Surah 2 · 3'), findsNothing); // no verse label in the bar
  });

  testWidgets('play/pause button toggles the playing verse', (tester) async {
    await pumpBar(tester);
    await playVerse(tester, 2003);

    await tester.tap(find.byKey(WidgetKeys.playerBarPlay));
    await settle(tester);
    expect(player.calls, contains('pause'));

    // Now paused — tapping again resumes.
    await tester.tap(find.byKey(WidgetKeys.playerBarPlay));
    await settle(tester);
    expect(player.calls, contains('resume'));
  });

  testWidgets('prev / next walk the section sequence', (tester) async {
    await pumpBar(tester);
    await playVerse(tester, 2003);

    await tester.tap(find.byKey(WidgetKeys.playerBarNext));
    await settle(tester);
    expect(player.lastPlayed, 2004);

    await tester.tap(find.byKey(WidgetKeys.playerBarPrev));
    await settle(tester);
    expect(player.lastPlayed, 2003);
  });

  testWidgets('speed menu sets the playback rate', (tester) async {
    await pumpBar(tester);
    await playVerse(tester, 2003);
    // The bar's speed button shows the current rate; tapping opens the presets.
    expect(find.text('1×'), findsWidgets);
    await tester.tap(find.byKey(WidgetKeys.playerSpeed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.25×').last); // pick from the menu
    await settle(tester);
    expect(audio.state.speed, 1.25);
    expect(player.calls, contains('setSpeed(1.25)'));
  });

  testWidgets('repeat cycles off → verse → surah → off', (tester) async {
    await pumpBar(tester);
    await playVerse(tester, 2003);
    expect(audio.state.repeat, RecitationRepeat.off);

    await tester.tap(find.byKey(WidgetKeys.playerRepeat));
    await settle(tester);
    expect(audio.state.repeat, RecitationRepeat.one);
    expect(player.calls, contains('setLoopMode(one)'));

    await tester.tap(find.byKey(WidgetKeys.playerRepeat));
    await settle(tester);
    expect(audio.state.repeat, RecitationRepeat.all);
    // Surah loop is cubit-level, so the player loop mode goes back off.
    expect(player.calls, contains('setLoopMode(off)'));

    await tester.tap(find.byKey(WidgetKeys.playerRepeat));
    await settle(tester);
    expect(audio.state.repeat, RecitationRepeat.off);
  });
}
