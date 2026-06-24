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
}
