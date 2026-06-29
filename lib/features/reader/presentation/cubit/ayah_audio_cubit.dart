import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_recitation_player.dart';

part 'ayah_audio_state.dart';

/// Drives single-ayah recitation for the reader. Holds which verse is active and
/// its [RecitationStatus], re-emitted from the player's stream so the play buttons
/// + now-playing highlight stay in sync. Plugin-free (depends only on the
/// [AyahRecitationPlayer] interface) → unit-testable with a fake.
class AyahAudioCubit extends Cubit<AyahAudioState> {
  AyahAudioCubit(this._player) : super(const AyahAudioState()) {
    _sub = _player.playbackStream.listen(_onPlayback);
  }

  final AyahRecitationPlayer _player;
  StreamSubscription<RecitationPlayback>? _sub;

  // The active section's verse ids in reading order. Set by the reader whenever
  // the section loads/changes; drives continuous "play from here" advance.
  List<int> _sequence = const [];

  /// Teach the cubit the order of the verses on screen, so that when one finishes
  /// it can roll into the next. Idempotent; the reader re-pushes on load/swipe.
  void setSequence(List<int> ayahIds) => _sequence = ayahIds;

  /// The verse after [id] in the current sequence, or null at the end / when [id]
  /// isn't in the sequence (→ playback stops at the surah end).
  int? _nextAfter(int? id) {
    if (id == null) return null;
    final i = _sequence.indexOf(id);
    if (i < 0 || i + 1 >= _sequence.length) return null;
    return _sequence[i + 1];
  }

  void _onPlayback(RecitationPlayback p) {
    // A verse finished on its own: roll into the next one ("play from here"), or
    // stop at the surah end. Intercepted here so the UI never sees `completed`.
    if (p.status == RecitationStatus.completed) {
      final next = _nextAfter(p.ayahId);
      if (next != null) {
        _player.play(next); // continues: emits loading→playing for `next`
      } else {
        // End of surah → idle, clears the now-playing highlight.
        emit(const AyahAudioState());
      }
      return;
    }
    // While a verse plays, warm the NEXT one into the cache so "play from here"
    // rolls on without the per-verse network gap. Best-effort + idempotent in
    // the player (no-op when already cached / in flight / at the surah end).
    if (p.status == RecitationStatus.playing) {
      final next = _nextAfter(p.ayahId);
      if (next != null) _player.prefetch(next);
    }
    final isError = p.status == RecitationStatus.error;
    emit(
      AyahAudioState(
        playingAyahId: isError ? null : p.ayahId,
        status: p.status,
        errorAyahId: isError ? p.ayahId : null,
      ),
    );
  }

  /// The one entry point the play buttons call. Same verse → pause/resume (or
  /// retry after an error); a different verse → switch (stops the previous one).
  Future<void> toggle(int ayahId) async {
    final s = state;
    if (s.playingAyahId == ayahId) {
      switch (s.status) {
        case RecitationStatus.playing:
          await _player.pause();
        case RecitationStatus.paused:
          await _player.resume();
        case RecitationStatus.loading:
          break; // already loading this verse — ignore the tap
        case RecitationStatus.idle:
        case RecitationStatus
              .completed: // never actually held in state; for exhaustiveness
        case RecitationStatus.error:
          await _player.play(ayahId);
      }
    } else {
      await _player.play(ayahId);
    }
  }

  /// Stop playback entirely (e.g. on swipe to another section).
  Future<void> stopAll() => _player.stop();

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _player
        .stop(); // the player is a shared singleton — stop, don't dispose
    return super.close();
  }
}
