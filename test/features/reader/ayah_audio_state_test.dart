import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for [AyahAudioState.isSounding] — the gate the Reading peek uses to
/// decide whether its ‹/› verse stepper is locked (audio running) or free (the
/// reader can browse translations). Only `playing`/`loading` count as sounding;
/// `paused`, `idle`/stopped, `completed` and `error` must NOT — otherwise pausing
/// would trap the listener (see the peek arrow-gating widget test).
void main() {
  group('AyahAudioState.isSounding', () {
    test('true while a verse is playing', () {
      const state = AyahAudioState(
        playingAyahId: 8,
        status: RecitationStatus.playing,
      );
      expect(state.isSounding, isTrue);
    });

    test('true while a verse is loading/buffering', () {
      const state = AyahAudioState(
        playingAyahId: 8,
        status: RecitationStatus.loading,
      );
      expect(state.isSounding, isTrue);
    });

    test('false when paused (the reader can step + read translations)', () {
      const state = AyahAudioState(
        playingAyahId: 8,
        status: RecitationStatus.paused,
      );
      expect(state.isSounding, isFalse);
    });

    test('false when idle/stopped (default state)', () {
      expect(const AyahAudioState().isSounding, isFalse);
    });

    test('false on a completed track (playback finished)', () {
      const state = AyahAudioState(status: RecitationStatus.completed);
      expect(state.isSounding, isFalse);
    });

    test('false after an error', () {
      const state = AyahAudioState(
        status: RecitationStatus.error,
        errorAyahId: 8,
      );
      expect(state.isSounding, isFalse);
    });
  });
}
