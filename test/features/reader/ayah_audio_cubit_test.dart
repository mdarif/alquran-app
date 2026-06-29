import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
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

  @override
  Stream<RecitationPlayback> get playbackStream => _controller.stream;

  @override
  Future<void> play(int ayahId) async => calls.add('play($ayahId)');
  @override
  Future<void> prefetch(int ayahId) async => calls.add('prefetch($ayahId)');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
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
}
