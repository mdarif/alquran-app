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

/// Playback lifecycle for a single verse. `completed` is a one-shot signal the
/// track ended on its own (vs. `idle`, which `stop()` emits) — it carries the
/// finished verse id so continuous playback can advance to the next verse.
enum RecitationStatus { idle, loading, playing, paused, completed, error }

/// What the player is doing, and to which verse. `ayahId` is the global 1..6236
/// id; null when idle/stopped. Emitted on [AyahRecitationPlayer.playbackStream].
class RecitationPlayback extends Equatable {
  const RecitationPlayback({this.ayahId, this.status = RecitationStatus.idle});

  final int? ayahId;
  final RecitationStatus status;

  @override
  List<Object?> get props => [ayahId, status];
}

/// Playback position within the current verse's file, for the scrubber. Rides its
/// own stream (NOT the cubit's state) so a ~5×/s tick never rebuilds the reader.
class PlaybackProgress extends Equatable {
  const PlaybackProgress({
    this.position = Duration.zero,
    this.duration,
    this.buffered = Duration.zero,
  });

  final Duration position;
  final Duration? duration;
  final Duration buffered;

  @override
  List<Object?> get props => [position, duration, buffered];
}

/// Repeat mode at the player level. `one` loops the current verse's track; `off`
/// lets it complete (so the cubit can advance). Keeps just_audio's `LoopMode` out
/// of the interface. (Verse-RANGE repeat is cubit-level and not represented here.)
enum RecitationLoop { off, one }

/// Plays a single ayah's recitation, streaming + caching to disk. This is the
/// seam (mirrors `core/home_widget`'s `HomeWidgetClient`): everything else
/// depends on this interface so the plugin stays out of every test — never
/// construct [JustAudioRecitationPlayer] in test code.
abstract interface class AyahRecitationPlayer {
  /// Status updates keyed by the verse being played.
  Stream<RecitationPlayback> get playbackStream;

  /// Position/duration within the current verse's file (~5×/s while playing), for
  /// the scrubber. Separate from [playbackStream] to avoid rebuild storms.
  Stream<PlaybackProgress> get progressStream;

  /// Stream + cache the given verse and start playing it. Stops any previous one.
  Future<void> play(int ayahId);

  /// Pause / resume the current verse (no-op if nothing is loaded).
  Future<void> pause();
  Future<void> resume();

  /// Seek within the current verse's file.
  Future<void> seek(Duration position);

  /// Playback rate (1.0 = normal). Persisted by the cubit and applied to the
  /// shared player, so it holds across verses.
  Future<void> setSpeed(double speed);
  double get speed;

  /// Loop the current verse (`one`) or let it complete (`off`).
  Future<void> setLoopMode(RecitationLoop mode);

  /// Warm [ayahId] into the on-disk cache in the background (best-effort), so a
  /// later [play] of it starts without the per-verse network gap. No playback
  /// and no status events; safe to call repeatedly (a no-op when already cached
  /// or in flight). Used by continuous playback to pre-fetch the next verse.
  Future<void> prefetch(int ayahId);

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
    // Throttled position ticks (~5×/s) for the scrubber, off its own stream.
    _positionSub = _player
        .createPositionStream(
      minPeriod: const Duration(milliseconds: 200),
      maxPeriod: const Duration(milliseconds: 200),
    )
        .listen((pos) {
      if (_progressController.isClosed) return;
      _progressController.add(
        PlaybackProgress(
          position: pos,
          duration: _player.duration,
          buffered: _player.bufferedPosition,
        ),
      );
    });
  }

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<Duration>? _positionSub;
  final StreamController<RecitationPlayback> _controller =
      StreamController<RecitationPlayback>.broadcast();
  final StreamController<PlaybackProgress> _progressController =
      StreamController<PlaybackProgress>.broadcast();

  int? _currentAyahId;
  bool _loading = false;

  // Verses being warmed in the background (prefetch), so we never double-fetch.
  final Set<int> _prefetching = {};

  @override
  Stream<RecitationPlayback> get playbackStream => _controller.stream;

  @override
  Stream<PlaybackProgress> get progressStream => _progressController.stream;

  /// The deterministic on-disk cache file for [ayahId] — the SAME path both
  /// [play] (via [LockCachingAudioSource]) and [prefetch] write, so a warmed
  /// file is served straight from disk on the next play.
  Future<File> _cacheFileFor(int ayahId) async {
    final cacheRoot = await getApplicationCacheDirectory();
    return File(p.join(cacheRoot.path, recitationCacheRelativePath(ayahId)));
  }

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
        // Emit BEFORE clearing so the event carries the verse that just ended —
        // that's what the cubit needs to advance to the next one. Distinct from
        // the `idle` that stop() emits, so a natural end and a user stop don't
        // look the same.
        _emit(RecitationStatus.completed);
        _currentAyahId = null;
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
      cacheFile = await _cacheFileFor(ayahId);
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
  Future<void> prefetch(int ayahId) async {
    if (_prefetching.contains(ayahId)) return;
    final cacheFile = await _cacheFileFor(ayahId);
    if (await cacheFile.exists()) return; // already fully cached
    _prefetching.add(ayahId);
    // Download to a temp sibling and publish with an ATOMIC rename only on
    // success — an interrupted prefetch must never leave a truncated file at
    // cacheFile, which LockCachingAudioSource would then serve as if complete.
    final tmp = File('${cacheFile.path}.prefetch');
    HttpClient? client;
    try {
      await cacheFile.parent.create(recursive: true);
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(alafasyUrl(ayahId)));
      final response = await request.close();
      if (response.statusCode != 200) return;
      await response.pipe(tmp.openWrite()); // writes the body + closes the sink
      if (await cacheFile.exists()) {
        await tmp.delete(); // someone (a manual tap) beat us to it
      } else {
        await tmp.rename(cacheFile.path);
      }
    } catch (_) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {/* best-effort */}
    } finally {
      client?.close();
      _prefetching.remove(ayahId);
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
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  double get speed => _player.speed;

  @override
  Future<void> setLoopMode(RecitationLoop mode) => _player
      .setLoopMode(mode == RecitationLoop.one ? LoopMode.one : LoopMode.off);

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
    await _positionSub?.cancel();
    await _player.dispose();
    await _controller.close();
    await _progressController.close();
  }
}
