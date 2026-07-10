part of 'ayah_audio_cubit.dart';

/// Which verse is active and what it's doing. `playingAyahId` is the global
/// 1..6236 id; null when idle/stopped/errored. `errorAyahId` is set only on the
/// last failed verse so the reader can flag just that one.
class AyahAudioState extends Equatable {
  const AyahAudioState({
    this.playingAyahId,
    this.status = RecitationStatus.idle,
    this.errorAyahId,
    this.speed = 1.0,
    this.repeat = RecitationRepeat.off,
  });

  final int? playingAyahId;
  final RecitationStatus status;
  final int? errorAyahId;

  /// Transport settings (change only on user action → they never storm rebuilds;
  /// playback position/duration live on the player's progressStream, NOT here).
  final double speed;
  final RecitationRepeat repeat;

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

  /// A verse is actively sounding (playing) or about to (buffering). Paused,
  /// idle/stopped, completed and error do NOT count — so the Reading peek can
  /// free its ‹/› stepper for browsing translations whenever audio isn't running.
  bool get isSounding =>
      status == RecitationStatus.playing || status == RecitationStatus.loading;

  /// The last play attempt for this verse failed.
  bool hasError(int ayahId) => errorAyahId == ayahId;

  @override
  List<Object?> get props =>
      [playingAyahId, status, errorAyahId, speed, repeat];
}
