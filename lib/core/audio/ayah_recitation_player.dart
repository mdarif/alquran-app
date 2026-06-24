// LockCachingAudioSource is marked @experimental in just_audio but is the
// stable, documented way to stream-and-cache in one source (and the whole point
// of this feature). We pin just_audio (^0.9.46), so it won't shift under us.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'recitation_source.dart';

/// Playback lifecycle for a single verse.
enum RecitationStatus { idle, loading, playing, paused, error }

/// What the player is doing, and to which verse. `ayahId` is the global 1..6236
/// id; null when idle/stopped. Emitted on [AyahRecitationPlayer.playbackStream].
class RecitationPlayback extends Equatable {
  const RecitationPlayback({this.ayahId, this.status = RecitationStatus.idle});

  final int? ayahId;
  final RecitationStatus status;

  @override
  List<Object?> get props => [ayahId, status];
}

/// Plays a single ayah's recitation, streaming + caching to disk. This is the
/// seam (mirrors `core/home_widget`'s `HomeWidgetClient`): everything else
/// depends on this interface so the plugin stays out of every test — never
/// construct [JustAudioRecitationPlayer] in test code.
abstract interface class AyahRecitationPlayer {
  /// Status updates keyed by the verse being played.
  Stream<RecitationPlayback> get playbackStream;

  /// Stream + cache the given verse and start playing it. Stops any previous one.
  Future<void> play(int ayahId);

  /// Pause / resume the current verse (no-op if nothing is loaded).
  Future<void> pause();
  Future<void> resume();

  /// Stop and clear the current verse.
  Future<void> stop();

  /// Release the underlying player (app teardown).
  Future<void> dispose();
}

/// `just_audio`-backed implementation. The ONLY file importing `just_audio` /
/// `audio_session`. Uses [LockCachingAudioSource] so the first play streams while
/// writing to a deterministic cache file and replays resolve offline.
class JustAudioRecitationPlayer implements AyahRecitationPlayer {
  JustAudioRecitationPlayer() {
    _player = AudioPlayer(handleInterruptions: true);
    // Player state drives playing/paused/completed once a verse is loaded; the
    // explicit `_loading` window (during setAudioSource) is suppressed so the UI
    // shows a steady "loading" instead of flickering through ready/paused.
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    // Surface mid-stream failures (e.g. the network drops after caching started).
    _eventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object _, StackTrace __) => _emit(RecitationStatus.error),
    );
  }

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  final StreamController<RecitationPlayback> _controller =
      StreamController<RecitationPlayback>.broadcast();

  int? _currentAyahId;
  bool _loading = false;

  @override
  Stream<RecitationPlayback> get playbackStream => _controller.stream;

  void _emit(RecitationStatus status) {
    if (_controller.isClosed) return;
    _controller.add(RecitationPlayback(ayahId: _currentAyahId, status: status));
  }

  void _onPlayerState(PlayerState s) {
    if (_loading) return; // we drive the load window explicitly in play()
    switch (s.processingState) {
      case ProcessingState.idle:
        break; // emitted by stop(); handled there
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _emit(RecitationStatus.loading);
      case ProcessingState.ready:
        _emit(s.playing ? RecitationStatus.playing : RecitationStatus.paused);
      case ProcessingState.completed:
        _currentAyahId = null;
        _emit(RecitationStatus.idle);
    }
  }

  @override
  Future<void> play(int ayahId) async {
    _currentAyahId = ayahId;
    _loading = true;
    _emit(RecitationStatus.loading);
    File? cacheFile;
    try {
      await _player.stop(); // stop any previous verse (suppressed by _loading)
      final cacheRoot = await getApplicationCacheDirectory();
      cacheFile =
          File(p.join(cacheRoot.path, recitationCacheRelativePath(ayahId)));
      await cacheFile.parent.create(recursive: true);
      final source = LockCachingAudioSource(
        Uri.parse(alafasyUrl(ayahId)),
        cacheFile: cacheFile,
      );
      await _player.setAudioSource(source);
      unawaited(_player.play()); // play()'s Future completes at end-of-track
      _loading = false;
      _emit(RecitationStatus.playing);
    } catch (_) {
      _loading = false;
      // A throw with no cache file (or a partial one) = offline + not cached, or
      // a corrupt cache. Drop any partial file so the next attempt re-fetches.
      if (cacheFile != null) {
        try {
          if (cacheFile.existsSync()) cacheFile.deleteSync();
        } catch (_) {/* best-effort */}
      }
      _emit(RecitationStatus.error);
    }
  }

  @override
  Future<void> pause() async {
    if (_currentAyahId == null) return;
    await _player.pause();
    _emit(RecitationStatus.paused);
  }

  @override
  Future<void> resume() async {
    if (_currentAyahId == null) return;
    unawaited(_player.play());
    _emit(RecitationStatus.playing);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentAyahId = null;
    _emit(RecitationStatus.idle);
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _eventSub?.cancel();
    await _player.dispose();
    await _controller.close();
  }
}
