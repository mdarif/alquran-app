import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_recitation_player.dart';
import '../../domain/repositories/reader_settings_repository.dart';

part 'ayah_audio_state.dart';

/// How playback repeats. `off` plays straight through the surah, then hands off to
/// the next one (see [onSequenceEnd]); `one` loops the current verse; `all` loops
/// the whole surah (plays through, then restarts at the first verse). (Verse-range
/// repeat for hifz is a follow-up.)
enum RecitationRepeat { off, one, all }

/// Drives single-ayah recitation for the reader. Holds which verse is active and
/// its [RecitationStatus], re-emitted from the player's stream so the play buttons
/// + now-playing highlight stay in sync. Plugin-free (depends only on the
/// [AyahRecitationPlayer] interface) → unit-testable with a fake.
class AyahAudioCubit extends Cubit<AyahAudioState> {
  AyahAudioCubit(this._player, [this._settings])
      : super(const AyahAudioState()) {
    _sub = _player.playbackStream.listen(_onPlayback);
    // Restore the persisted playback speed and apply it to the shared player.
    final s = _settings;
    if (s != null) {
      _speed = s.recitationSpeed;
      unawaited(_player.setSpeed(_speed));
      emit(_withSettings(state));
    }
  }

  final AyahRecitationPlayer _player;
  final ReaderSettingsRepository? _settings;
  StreamSubscription<RecitationPlayback>? _sub;

  // The active section's verse ids in reading order. Set by the reader whenever
  // the section loads/changes; drives continuous "play from here" advance.
  List<int> _sequence = const [];

  // Transport settings — held as fields so the fresh states built in _onPlayback
  // carry them (never reset to defaults). Speed persists; repeat is session-only.
  double _speed = 1.0;
  RecitationRepeat _repeat = RecitationRepeat.off;

  /// Autoplay reached the section's LAST verse with nothing left in this section:
  /// the reader hooks this to roll into the next surah (the cubit only knows one
  /// section at a time). Null, or no next section → playback simply ends. Not
  /// invoked under repeat-verse (loops at the player) or repeat-surah (loops here).
  void Function()? onSequenceEnd;

  /// Playback position/duration for the bar's 2px progress line — a separate
  /// stream so its ~5×/s tick never rebuilds the reader (state carries no position).
  Stream<PlaybackProgress> get progress => _player.progressStream;

  // Re-stamp a state with the current transport settings.
  AyahAudioState _withSettings(AyahAudioState s) => AyahAudioState(
        playingAyahId: s.playingAyahId,
        status: s.status,
        errorAyahId: s.errorAyahId,
        speed: _speed,
        repeat: _repeat,
      );

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

  /// The verse before [id] in the current sequence, or null at the start.
  int? _prevBefore(int? id) {
    if (id == null) return null;
    final i = _sequence.indexOf(id);
    return i <= 0 ? null : _sequence[i - 1];
  }

  void _onPlayback(RecitationPlayback p) {
    // A verse finished on its own: advance (autoplay is always on). Intercepted
    // here so the UI never sees `completed`. (repeat-verse loops at the player,
    // so `completed` won't even fire for it.)
    if (p.status == RecitationStatus.completed) {
      int? next;
      if (_repeat == RecitationRepeat.all) {
        // Loop the surah: roll to the next verse, or back to the first at the end.
        next = _nextAfter(p.ayahId) ??
            (_sequence.isNotEmpty ? _sequence.first : null);
      } else {
        // Autoplay is ALWAYS on (no single-verse mode; pause is the only stop).
        // Roll to the next verse; at the surah's LAST verse hand off to the reader
        // to roll into the next surah (keeping the non-idle state so the bar
        // doesn't flicker during the hand-off).
        next = _nextAfter(p.ayahId);
        if (next == null && onSequenceEnd != null) {
          onSequenceEnd!.call();
          return;
        }
      }
      if (next != null) {
        _player.play(next); // continues: emits loading→playing for `next`
      } else {
        // Nothing left to play (last verse, no next-section hand-off) → idle
        // (keeps transport settings).
        emit(_withSettings(const AyahAudioState()));
      }
      return;
    }
    // While a verse plays, warm the NEXT one into the cache so continuous play
    // rolls on without the per-verse network gap. Best-effort + idempotent in
    // the player (no-op when already cached / in flight / at the surah end).
    if (p.status == RecitationStatus.playing) {
      final next = _nextAfter(p.ayahId);
      if (next != null) _player.prefetch(next);
    }
    final isError = p.status == RecitationStatus.error;
    emit(
      _withSettings(
        AyahAudioState(
          playingAyahId: isError ? null : p.ayahId,
          status: p.status,
          errorAyahId: isError ? p.ayahId : null,
        ),
      ),
    );
  }

  /// Play the previous / next verse in the section (no-op at the bounds). Used by
  /// the player bar's ‹/› transport controls.
  Future<void> playNext() async {
    final n = _nextAfter(state.playingAyahId);
    if (n != null) await _player.play(n);
  }

  Future<void> playPrevious() async {
    final p = _prevBefore(state.playingAyahId);
    if (p != null) await _player.play(p);
  }

  /// Seek within the current verse's file. A player capability with no UI in the
  /// slim bar (the scrubber was retired); kept for a future scrub/verse-progress UI.
  Future<void> seek(Duration position) => _player.seek(position);

  /// Set the playback rate (persisted; applied to the shared player).
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    emit(_withSettings(state));
    await _player.setSpeed(speed);
    await _settings?.setRecitationSpeed(speed);
  }

  /// Set the repeat mode (session-only). `one` loops the current verse via the
  /// player's loop mode, so it never `completed`s.
  Future<void> setRepeat(RecitationRepeat mode) async {
    _repeat = mode;
    emit(_withSettings(state));
    await _player.setLoopMode(
      mode == RecitationRepeat.one ? RecitationLoop.one : RecitationLoop.off,
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

  /// Pause the current verse if it is actively playing — called when the app goes
  /// to the background. Recitation is foreground-only (no background audio
  /// service), so this keeps the UI honest: you return to a verse you can resume,
  /// not a now-playing highlight over silence. No-op unless a verse is playing
  /// (buffering/paused/idle are left untouched).
  Future<void> pauseForBackground() async {
    if (state.status == RecitationStatus.playing) await _player.pause();
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _player
        .stop(); // the player is a shared singleton — stop, don't dispose
    return super.close();
  }
}
