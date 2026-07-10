import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the cubit asks of the player and lets a test push playback
/// events back — no just_audio plugin in sight (that's the whole point of the
/// AyahRecitationPlayer seam).
class _FakePlayer implements AyahRecitationPlayer {
  final StreamController<RecitationPlayback> _controller =
      StreamController<RecitationPlayback>.broadcast();
  final List<String> calls = [];

  void push(int? ayahId, RecitationStatus status) =>
      _controller.add(RecitationPlayback(ayahId: ayahId, status: status));

  final StreamController<PlaybackProgress> progress =
      StreamController<PlaybackProgress>.broadcast();
  double _speed = 1.0;

  @override
  Stream<RecitationPlayback> get playbackStream => _controller.stream;

  @override
  Stream<PlaybackProgress> get progressStream => progress.stream;

  @override
  Future<void> play(int ayahId) async => calls.add('play($ayahId)');
  @override
  Future<void> prefetch(int ayahId) async => calls.add('prefetch($ayahId)');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek(${position.inMilliseconds})');
  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    calls.add('setSpeed($speed)');
  }

  @override
  double get speed => _speed;
  @override
  Future<void> setLoopMode(RecitationLoop mode) async =>
      calls.add('setLoopMode(${mode.name})');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  late _FakePlayer player;
  late AyahAudioCubit cubit;

  setUp(() {
    player = _FakePlayer();
    cubit = AyahAudioCubit(player);
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('toggle on idle plays the verse', () async {
    await cubit.toggle(8);
    expect(player.calls, ['play(8)']);
  });

  test('the player stream drives state: loading -> playing', () async {
    player.push(8, RecitationStatus.loading);
    await pumpEventQueue();
    expect(cubit.state.playingAyahId, 8);
    expect(cubit.state.isLoading(8), true);

    player.push(8, RecitationStatus.playing);
    await pumpEventQueue();
    expect(cubit.state.isPlaying(8), true);
  });

  test('toggling the playing verse pauses it', () async {
    await cubit.toggle(8);
    player.push(8, RecitationStatus.playing);
    await pumpEventQueue();

    await cubit.toggle(8);
    expect(player.calls, ['play(8)', 'pause']);
  });

  test('toggling a paused verse resumes it', () async {
    await cubit.toggle(8);
    player.push(8, RecitationStatus.paused);
    await pumpEventQueue();

    await cubit.toggle(8);
    expect(player.calls, ['play(8)', 'resume']);
  });

  test('toggling a different verse switches (play, not pause)', () async {
    await cubit.toggle(8);
    player.push(8, RecitationStatus.playing);
    await pumpEventQueue();

    await cubit.toggle(9);
    expect(player.calls, ['play(8)', 'play(9)']);
  });

  test('a loading verse ignores re-taps (no double-load)', () async {
    await cubit.toggle(8);
    player.push(8, RecitationStatus.loading);
    await pumpEventQueue();

    await cubit.toggle(8);
    expect(player.calls, ['play(8)']); // no second play/pause
  });

  test('error surfaces as errorAyahId and clears playingAyahId', () async {
    player.push(8, RecitationStatus.error);
    await pumpEventQueue();
    expect(cubit.state.playingAyahId, isNull);
    expect(cubit.state.errorAyahId, 8);
    expect(cubit.state.hasError(8), true);
  });

  test('toggling an errored verse retries (play)', () async {
    player.push(8, RecitationStatus.error);
    await pumpEventQueue();

    await cubit.toggle(8);
    expect(player.calls, ['play(8)']);
  });

  test('close stops playback', () async {
    await cubit.close();
    expect(player.calls, contains('stop'));
  });

  group('continuous "play from here" auto-advance', () {
    test('a finished verse rolls into the next one in the sequence', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(1); // play(1)

      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();
      expect(player.calls, ['play(1)', 'play(2)']);

      player.push(2, RecitationStatus.completed);
      await pumpEventQueue();
      expect(player.calls, ['play(1)', 'play(2)', 'play(3)']);
    });

    test('the last verse stops (no advance, idle state)', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(3); // jump straight to the last verse
      player.push(3, RecitationStatus.playing);
      await pumpEventQueue();

      player.push(3, RecitationStatus.completed);
      await pumpEventQueue();

      expect(player.calls, ['play(3)']); // nothing after the last verse
      expect(cubit.state.playingAyahId, isNull); // highlight cleared
      expect(cubit.state.status, RecitationStatus.idle);
    });

    test('completion of an unknown verse stops (no sequence match)', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(1);

      player.push(99, RecitationStatus.completed); // not in the sequence
      await pumpEventQueue();

      expect(player.calls, ['play(1)']);
      expect(cubit.state.playingAyahId, isNull);
    });

    test('pause does NOT auto-advance', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(1);

      player.push(1, RecitationStatus.paused);
      await pumpEventQueue();

      expect(player.calls, ['play(1)']); // no play(2)
      expect(cubit.state.isPaused(1), true);
    });

    test('an error does NOT auto-advance past the failed verse', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(1);

      player.push(1, RecitationStatus.error);
      await pumpEventQueue();

      expect(player.calls, ['play(1)']); // no play(2)
      expect(cubit.state.hasError(1), true);
    });

    test('a playing verse warms the next one (prefetch)', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(1);

      player.push(1, RecitationStatus.playing);
      await pumpEventQueue();

      expect(player.calls, contains('prefetch(2)'));
    });

    test('the last verse warms nothing (no prefetch past the end)', () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.toggle(3);

      player.push(3, RecitationStatus.playing);
      await pumpEventQueue();

      expect(player.calls.any((c) => c.startsWith('prefetch')), isFalse);
    });

    test('completed status never surfaces in the cubit state', () async {
      cubit.setSequence([1, 2]);
      await cubit.toggle(1);

      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();

      // The cubit acted on it (play(2)); the UI only ever sees the next verse
      // loading/playing — never a lingering `completed`.
      expect(cubit.state.status, isNot(RecitationStatus.completed));
    });
  });

  group('transport', () {
    Future<void> playing(int id) async {
      await cubit.toggle(id);
      player.push(id, RecitationStatus.playing);
      await pumpEventQueue();
    }

    test('playNext / playPrevious walk the sequence', () async {
      cubit.setSequence([1, 2, 3]);
      await playing(2);
      player.calls.clear();

      await cubit.playNext();
      expect(player.calls, ['play(3)']);
      await cubit.playPrevious();
      expect(player.calls, ['play(3)', 'play(1)']);
    });

    test('playNext at the last verse is a no-op; playPrevious at the first too',
        () async {
      cubit.setSequence([1, 2, 3]);
      await playing(3);
      player.calls.clear();
      await cubit.playNext();
      expect(player.calls, isEmpty);

      await playing(1);
      player.calls.clear();
      await cubit.playPrevious();
      expect(player.calls, isEmpty);
    });

    test('seek forwards to the player', () async {
      await cubit.seek(const Duration(seconds: 3));
      expect(player.calls, contains('seek(3000)'));
    });

    test('setSpeed updates state and forwards to the player', () async {
      await cubit.setSpeed(1.5);
      expect(cubit.state.speed, 1.5);
      expect(player.calls, contains('setSpeed(1.5)'));
      expect(player.speed, 1.5);
    });

    test('setRepeat(one) loops at the player; the verse never advances',
        () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.setRepeat(RecitationRepeat.one);
      expect(cubit.state.repeat, RecitationRepeat.one);
      expect(player.calls, contains('setLoopMode(one)'));
      // With repeat-one the player loops → `completed` never fires, so there is
      // nothing to advance. setRepeat(off) restores normal completion.
      await cubit.setRepeat(RecitationRepeat.off);
      expect(player.calls, contains('setLoopMode(off)'));
    });

    test('continuous off → a finished verse stops instead of advancing',
        () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.setContinuous(false);
      expect(cubit.state.continuousPlay, false);
      await playing(1);
      player.calls.clear();

      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();
      expect(player.calls, isEmpty); // did NOT play(2)
      expect(cubit.state.playingAyahId, isNull); // idle
      // setting preserved through the idle rebuild
      expect(cubit.state.continuousPlay, false);
    });

    test('transport settings survive playback-event rebuilds', () async {
      await cubit.setSpeed(1.25);
      cubit.setSequence([1, 2]);
      player.push(1, RecitationStatus.playing);
      await pumpEventQueue();
      // A fresh playback event must NOT reset speed to the default.
      expect(cubit.state.speed, 1.25);
    });
  });

  group('persisted settings', () {
    test('restores speed + continuous and applies speed to the player on open',
        () async {
      final settings = _FakeSettings(speed: 1.75, continuous: false);
      final p = _FakePlayer();
      final c = AyahAudioCubit(p, settings);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      await pumpEventQueue();
      expect(c.state.speed, 1.75);
      expect(c.state.continuousPlay, false);
      expect(p.calls, contains('setSpeed(1.75)'));
    });

    test('setSpeed / setContinuous persist', () async {
      final settings = _FakeSettings();
      final p = _FakePlayer();
      final c = AyahAudioCubit(p, settings);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      await c.setSpeed(2.0);
      await c.setContinuous(false);
      expect(settings.recitationSpeed, 2.0);
      expect(settings.continuousRecitation, false);
    });
  });
}

/// In-memory settings fake for the persistence tests — mutable fields so the
/// cubit's writes are observable (mirrors the fake used across the reader tests).
class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({double speed = 1.0, bool continuous = true})
      : recitationSpeed = speed,
        continuousRecitation = continuous;

  @override
  double recitationSpeed;
  @override
  bool continuousRecitation;
  @override
  double fontSize = 24;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations = const [];
  @override
  bool readingTranslationVisible = true;
  @override
  ArabicScript script = ArabicScript.uthmani;

  @override
  Future<void> setRecitationSpeed(double value) async =>
      recitationSpeed = value;
  @override
  Future<void> setContinuousRecitation(bool value) async =>
      continuousRecitation = value;
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
  Future<void> setReadingTranslationVisible(bool value) async =>
      readingTranslationVisible = value;
}
