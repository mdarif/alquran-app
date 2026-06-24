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

  void _onPlayback(RecitationPlayback p) {
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
