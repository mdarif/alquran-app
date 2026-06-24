part of 'ayah_audio_cubit.dart';

/// Which verse is active and what it's doing. `playingAyahId` is the global
/// 1..6236 id; null when idle/stopped/errored. `errorAyahId` is set only on the
/// last failed verse so the reader can flag just that one.
class AyahAudioState extends Equatable {
  const AyahAudioState({
    this.playingAyahId,
    this.status = RecitationStatus.idle,
    this.errorAyahId,
  });

  final int? playingAyahId;
  final RecitationStatus status;
  final int? errorAyahId;

  /// The active verse is actually sounding.
  bool isPlaying(int ayahId) =>
      playingAyahId == ayahId && status == RecitationStatus.playing;

  /// The active verse is loaded but paused.
  bool isPaused(int ayahId) =>
      playingAyahId == ayahId && status == RecitationStatus.paused;

  /// The active verse is still buffering/streaming.
  bool isLoading(int ayahId) =>
      playingAyahId == ayahId && status == RecitationStatus.loading;

  /// This verse is the active one (used to drive the now-playing tint).
  bool isActive(int ayahId) => playingAyahId == ayahId;

  /// The last play attempt for this verse failed.
  bool hasError(int ayahId) => errorAyahId == ayahId;

  @override
  List<Object?> get props => [playingAyahId, status, errorAyahId];
}
