// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'translation_audio_source.dart';

/// Plays a single translation-audio clip to completion. Deliberately a
/// one-shot, no-status-stream interface (unlike [AyahRecitationPlayer]) —
/// the cubit only ever awaits one clip at a time, between an Arabic verse
/// completing and the chain advancing to the next verse. See
/// `docs/translation-audio-chaining-plan.md` for the full design; streams +
/// caches from R2, covering the full Quran as of Phase 3.
abstract interface class TranslationAudioPlayer {
  /// Stream + cache the Sahih International clip for [surah]/[ayah] and
  /// complete when it finishes. Stopping mid-play (e.g. [stop]) completes the
  /// future early without throwing. A network/cache failure is swallowed —
  /// this segment is skipped silently and the chain continues (plan decision
  /// #5: a missing/failed translation-audio segment must never stop or
  /// disable the whole chain).
  Future<void> play({required int surah, required int ayah});

  /// Stop playback immediately (e.g. the reader navigates away mid-chain).
  Future<void> stop();
}

/// `just_audio`-backed implementation, separate from
/// [JustAudioRecitationPlayer]'s shared player instance so translation-audio
/// playback never contends with the cached-streaming Arabic player's state
/// machine. Uses [LockCachingAudioSource] — same stream+cache pattern as
/// [JustAudioRecitationPlayer] — so the first play streams from R2 while
/// writing a deterministic cache file, and replays resolve offline.
class JustAudioTranslationPlayer implements TranslationAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<File> _cacheFileFor(int surah, int ayah) async {
    final cacheRoot = await getApplicationCacheDirectory();
    return File(
      p.join(
        cacheRoot.path,
        translationAudioCacheRelativePath(surah: surah, ayah: ayah),
      ),
    );
  }

  @override
  Future<void> play({required int surah, required int ayah}) async {
    File? cacheFile;
    try {
      cacheFile = await _cacheFileFor(surah, ayah);
      await cacheFile.parent.create(recursive: true);
      final source = LockCachingAudioSource(
        Uri.parse(translationAudioUrl(surah: surah, ayah: ayah)),
        cacheFile: cacheFile,
      );
      await _player.setAudioSource(source);
      final done = _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      );
      unawaited(_player.play());
      await done;
    } catch (_) {
      // Offline, a 404, or a corrupt partial cache — drop any partial file so
      // a later retry re-fetches instead of serving a truncated clip, and let
      // the caller's chain move on as if this segment simply wasn't there.
      if (cacheFile != null) {
        try {
          if (cacheFile.existsSync()) cacheFile.deleteSync();
        } catch (_) {/* best-effort */}
      }
    }
  }

  @override
  Future<void> stop() => _player.stop();
}
