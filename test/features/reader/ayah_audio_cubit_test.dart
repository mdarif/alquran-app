import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/audio/translation_audio_player.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the cubit asks for and lets a test control when a clip
/// "finishes" (via [completeCurrent]) — mirrors [_FakePlayer]'s role but for
/// the one-shot translation-audio player (no status stream needed since the
/// cubit only ever awaits one clip at a time).
class _FakeTranslationPlayer implements TranslationAudioPlayer {
  final List<String> calls = [];
  Completer<void>? _pending;

  @override
  Future<void> play({required int surah, required int ayah}) {
    calls.add('play(surah: $surah, ayah: $ayah)');
    _pending = Completer<void>();
    return _pending!.future;
  }

  void completeCurrent() => _pending?.complete();

  @override
  Future<void> stop() async => calls.add('stop');
}

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

    test('repeat-all loops the surah: the last verse rolls back to the first',
        () async {
      cubit.setSequence([1, 2, 3]);
      await cubit.setRepeat(RecitationRepeat.all);
      await playing(3);
      player.calls.clear();

      // The last verse finishing wraps to the first (not idle) — repeat-all
      // overrides the hand-off-at-end.
      player.push(3, RecitationStatus.completed);
      await pumpEventQueue();
      expect(player.calls, ['play(1)']);
    });

    test('autoplay at the section end hands off (onSequenceEnd), not idle',
        () async {
      var handoffs = 0;
      cubit.onSequenceEnd = () => handoffs++;
      cubit.setSequence([1, 2, 3]);
      await playing(3); // the last verse of the section
      player.calls.clear();

      player.push(3, RecitationStatus.completed);
      await pumpEventQueue();
      // Nothing left IN this section → hand off to the reader for the next surah;
      // the cubit does NOT go idle (the reader plays the next section's verse 1).
      expect(handoffs, 1);
      expect(player.calls, isEmpty);
      // Still shows the last verse during the hand-off.
      expect(cubit.state.playingAyahId, 3);
    });

    test('onSequenceEnd fires only at the last verse, not mid-surah', () async {
      var handoffs = 0;
      cubit.onSequenceEnd = () => handoffs++;
      cubit.setSequence([1, 2, 3]);
      await playing(1);
      player.calls.clear();

      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();
      expect(handoffs, 0);
      expect(player.calls, ['play(2)']); // rolled on within the section
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

  group('translation-audio chaining', () {
    test('plays translation audio between Arabic completion and the next verse',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([1, 2, 3]); // global ids 1-3 = Fatiha 1:1-1:3
      c.setAyahLocations([
        (id: 1, surah: 1, ayahNumber: 1),
        (id: 2, surah: 1, ayahNumber: 2),
        (id: 3, surah: 1, ayahNumber: 3),
      ]);
      c.setTranslationAudioEnabled(true);

      await c.toggle(1);
      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();

      expect(translation.calls, [
        'play(surah: 1, ayah: 1)',
      ]);
      expect(player.calls, ['play(1)']); // next verse withheld mid-chain

      translation.completeCurrent();
      await pumpEventQueue();
      expect(player.calls, ['play(1)', 'play(2)']);
    });

    // Phase 3 (full-Quran rollout): chaining is no longer hardcoded to
    // Al-Fatihah — any verse the reader has pushed a location for chains,
    // using its real surah/ayah number rather than the old global-id shortcut.
    test('chains correctly for a verse outside Al-Fatihah (Baqarah 2:1)',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([8, 9]); // global id 8 = Baqarah 2:1
      c.setAyahLocations([
        (id: 8, surah: 2, ayahNumber: 1),
        (id: 9, surah: 2, ayahNumber: 2),
      ]);
      c.setTranslationAudioEnabled(true);

      await c.toggle(8);
      player.push(8, RecitationStatus.completed);
      await pumpEventQueue();

      expect(translation.calls, ['play(surah: 2, ayah: 1)']);
      expect(player.calls, ['play(8)']); // withheld mid-chain

      translation.completeCurrent();
      await pumpEventQueue();
      expect(player.calls, ['play(8)', 'play(9)']);
    });

    group('translation audio during continuous playback (decision #3)', () {
      test(
          'defaults to on: chains for both the tapped verse and autoplay '
          'past it', () async {
        final translation = _FakeTranslationPlayer();
        final c = AyahAudioCubit(player, null, translation);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        c.setSequence([1, 2, 3]);
        c.setAyahLocations([
          (id: 1, surah: 1, ayahNumber: 1),
          (id: 2, surah: 1, ayahNumber: 2),
          (id: 3, surah: 1, ayahNumber: 3),
        ]);
        c.setTranslationAudioEnabled(true);

        await c.toggle(1); // manually tapped
        player.push(1, RecitationStatus.completed);
        await pumpEventQueue();
        translation.completeCurrent();
        await pumpEventQueue(); // rolls autoplay onto verse 2

        player.push(2, RecitationStatus.completed);
        await pumpEventQueue();
        // Verse 2 was reached by autoplay, not a tap — still chains by default.
        expect(translation.calls, [
          'play(surah: 1, ayah: 1)',
          'play(surah: 1, ayah: 2)',
        ]);
      });

      test(
          'off: the manually-tapped verse still chains, but autoplay past it '
          'does not', () async {
        final translation = _FakeTranslationPlayer();
        final c = AyahAudioCubit(player, null, translation);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        c.setSequence([1, 2, 3]);
        c.setAyahLocations([
          (id: 1, surah: 1, ayahNumber: 1),
          (id: 2, surah: 1, ayahNumber: 2),
          (id: 3, surah: 1, ayahNumber: 3),
        ]);
        c.setTranslationAudioEnabled(true);
        await c.setTranslationAudioDuringContinuousPlayback(false);

        await c.toggle(1); // manually tapped: chains regardless
        player.push(1, RecitationStatus.completed);
        await pumpEventQueue();
        expect(translation.calls, ['play(surah: 1, ayah: 1)']);
        translation.completeCurrent();
        await pumpEventQueue(); // autoplay rolls onto verse 2 (no chain to await)
        expect(player.calls, ['play(1)', 'play(2)']);

        player.push(2, RecitationStatus.completed);
        await pumpEventQueue();
        // Verse 2 was reached by autoplay — no translation clip requested for it,
        // and playback proceeds straight to verse 3 without waiting.
        expect(translation.calls, ['play(surah: 1, ayah: 1)']);
        expect(player.calls, ['play(1)', 'play(2)', 'play(3)']);
      });

      test('off: tapping a NEW verse mid-playback resets which verse chains',
          () async {
        final translation = _FakeTranslationPlayer();
        final c = AyahAudioCubit(player, null, translation);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        c.setSequence([1, 2, 3]);
        c.setAyahLocations([
          (id: 1, surah: 1, ayahNumber: 1),
          (id: 2, surah: 1, ayahNumber: 2),
          (id: 3, surah: 1, ayahNumber: 3),
        ]);
        c.setTranslationAudioEnabled(true);
        await c.setTranslationAudioDuringContinuousPlayback(false);

        // Jump straight to verse 3 by tapping it directly.
        await c.toggle(3);
        player.push(3, RecitationStatus.completed);
        await pumpEventQueue();
        expect(translation.calls, ['play(surah: 1, ayah: 3)']);
      });

      test('setting persists via the settings repository', () async {
        final settings = _FakeSettings();
        final c = AyahAudioCubit(player, settings);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        await c.setTranslationAudioDuringContinuousPlayback(false);
        expect(settings.translationAudioDuringContinuousPlayback, isFalse);
      });

      test('restores the persisted value on open', () async {
        final settings = _FakeSettings()
          ..translationAudioDuringContinuousPlayback = false;
        final translation = _FakeTranslationPlayer();
        final c = AyahAudioCubit(player, settings, translation);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        c.setSequence([1, 2]);
        c.setAyahLocations([
          (id: 1, surah: 1, ayahNumber: 1),
          (id: 2, surah: 1, ayahNumber: 2),
        ]);
        c.setTranslationAudioEnabled(true);

        await c.toggle(1);
        player.push(1, RecitationStatus.completed);
        await pumpEventQueue();
        translation.completeCurrent();
        await pumpEventQueue();

        player.push(2, RecitationStatus.completed);
        await pumpEventQueue();
        // Restored setting was already off, so verse 2 (reached by autoplay)
        // never requests translation audio.
        expect(translation.calls, ['play(surah: 1, ayah: 1)']);
      });

      test('playNext counts as a manual play: the new verse still chains',
          () async {
        final translation = _FakeTranslationPlayer();
        final c = AyahAudioCubit(player, null, translation);
        addTearDown(() async {
          if (!c.isClosed) await c.close();
        });
        c.setSequence([1, 2, 3]);
        c.setAyahLocations([
          (id: 1, surah: 1, ayahNumber: 1),
          (id: 2, surah: 1, ayahNumber: 2),
          (id: 3, surah: 1, ayahNumber: 3),
        ]);
        c.setTranslationAudioEnabled(true);
        await c.setTranslationAudioDuringContinuousPlayback(false);

        await c.toggle(1);
        player.push(1, RecitationStatus.playing);
        await pumpEventQueue();

        await c.playNext(); // explicit transport tap, not autoplay
        player.push(2, RecitationStatus.completed);
        await pumpEventQueue();
        expect(translation.calls, ['play(surah: 1, ayah: 2)']);
      });
    });

    // Decision #5: a missing/failed translation-audio segment is skipped, not
    // fatal — the chain must still roll on to the next verse. The real
    // player swallows failures internally (JustAudioTranslationPlayer.play);
    // this fake models the same contract by simply completing its future
    // without the cubit needing to know play() "failed" vs. "finished".
    test('a translation-audio segment that fails to play does not stall the chain',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([1, 2]);
      c.setAyahLocations([
        (id: 1, surah: 1, ayahNumber: 1),
        (id: 2, surah: 1, ayahNumber: 2),
      ]);
      c.setTranslationAudioEnabled(true);

      await c.toggle(1);
      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();
      expect(translation.calls, ['play(surah: 1, ayah: 1)']);
      expect(player.calls, ['play(1)']); // withheld awaiting the segment

      // The segment "fails" (network/404) — the real player swallows this and
      // completes its future rather than throwing; the chain must still move on.
      translation.completeCurrent();
      await pumpEventQueue();
      expect(player.calls, ['play(1)', 'play(2)']);
    });

    test('toggle off skips translation audio entirely (unchanged behavior)',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([1, 2, 3]);
      c.setAyahLocations([
        (id: 1, surah: 1, ayahNumber: 1),
        (id: 2, surah: 1, ayahNumber: 2),
        (id: 3, surah: 1, ayahNumber: 3),
      ]);

      await c.toggle(1);
      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();

      expect(translation.calls, isEmpty);
      expect(player.calls, ['play(1)', 'play(2)']);
    });

    test(
        'repeat-one with translation audio on replays the FULL chain, not just Arabic',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([1, 2, 3]);
      c.setAyahLocations([
        (id: 1, surah: 1, ayahNumber: 1),
        (id: 2, surah: 1, ayahNumber: 2),
        (id: 3, surah: 1, ayahNumber: 3),
      ]);
      c.setTranslationAudioEnabled(true);
      await c.setRepeat(RecitationRepeat.one);

      await c.toggle(1);
      player.push(1, RecitationStatus.playing);
      await pumpEventQueue();
      // Verse 1 has a known location with translation audio on → chaining is
      // needed, so once it starts playing the player's native loop must be
      // synced OFF (it would otherwise loop silently and never let the
      // translation clip play). setRepeat(one) earlier set it ON by default
      // (nothing was playing yet to know chaining applied) — this corrects it.
      expect(player.calls.last, 'setLoopMode(off)');

      player.push(1, RecitationStatus.completed);
      await pumpEventQueue();

      expect(translation.calls, [
        'play(surah: 1, ayah: 1)',
      ]);
      translation.completeCurrent();
      await pumpEventQueue();
      // Replays the SAME verse (not verse 2) — repeat-one, not autoplay.
      expect(
        player.calls.where((c) => c.startsWith('play(')),
        ['play(1)', 'play(1)'],
      );
    });

    test('repeat-one with translation audio off loops at the player as before',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([1, 2, 3]);
      c.setAyahLocations([
        (id: 1, surah: 1, ayahNumber: 1),
        (id: 2, surah: 1, ayahNumber: 2),
        (id: 3, surah: 1, ayahNumber: 3),
      ]);
      await c.setRepeat(RecitationRepeat.one);
      expect(player.calls, contains('setLoopMode(one)'));

      await c.toggle(1);
      player.push(1, RecitationStatus.playing);
      await pumpEventQueue();

      expect(translation.calls, isEmpty);
      expect(
        player.calls.where((c) => !c.startsWith('prefetch(')),
        ['setLoopMode(one)', 'play(1)'],
      );
    });

    test('a verse with no known location never plays translation audio',
        () async {
      final translation = _FakeTranslationPlayer();
      final c = AyahAudioCubit(player, null, translation);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      c.setSequence([8, 9]); // no setAyahLocations call — locations unknown
      c.setTranslationAudioEnabled(true);

      await c.toggle(8);
      player.push(8, RecitationStatus.completed);
      await pumpEventQueue();

      expect(translation.calls, isEmpty);
      expect(player.calls, ['play(8)', 'play(9)']);
    });
  });

  group('persisted settings', () {
    test('restores speed and applies it to the player on open', () async {
      final settings = _FakeSettings(speed: 1.75);
      final p = _FakePlayer();
      final c = AyahAudioCubit(p, settings);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      await pumpEventQueue();
      expect(c.state.speed, 1.75);
      expect(p.calls, contains('setSpeed(1.75)'));
    });

    test('setSpeed persists', () async {
      final settings = _FakeSettings();
      final p = _FakePlayer();
      final c = AyahAudioCubit(p, settings);
      addTearDown(() async {
        if (!c.isClosed) await c.close();
      });
      await c.setSpeed(2.0);
      expect(settings.recitationSpeed, 2.0);
    });
  });
}

/// In-memory settings fake for the persistence tests — mutable fields so the
/// cubit's writes are observable (mirrors the fake used across the reader tests).
class _FakeSettings implements ReaderSettingsRepository {
  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
  _FakeSettings({double speed = 1.0}) : recitationSpeed = speed;

  @override
  double recitationSpeed;
  @override
  double fontSize = 24;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations = const [];
  @override
  ArabicScript script = ArabicScript.uthmani;

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
