// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Plays a single translation-audio clip to completion. Deliberately a
/// one-shot, no-status-stream interface (unlike [AyahRecitationPlayer]) —
/// the Al-Fatihah POC only ever awaits one clip at a time, between an Arabic
/// verse completing and the chain advancing to the next verse. See
/// `docs/translation-audio-chaining-plan.md` for the full design; this is
/// Phase 2's narrow POC surface only (bundled local asset, no streaming/cache).
abstract interface class TranslationAudioPlayer {
  /// Play [assetPath] (a Flutter asset, e.g. from
  /// `sahihInternationalAssetPath`) and complete when it finishes. Stopping
  /// mid-play (e.g. [stop]) completes the future early without throwing.
  Future<void> playAsset(String assetPath);

  /// Stop playback immediately (e.g. the reader navigates away mid-chain).
  Future<void> stop();
}

/// `just_audio`-backed implementation, separate from
/// [JustAudioRecitationPlayer]'s shared player instance so translation-audio
/// playback (POC, local assets) never contends with the cached-streaming
/// Arabic player's state machine.
class JustAudioTranslationPlayer implements TranslationAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playAsset(String assetPath) async {
    await _player.setAsset(assetPath);
    final done = _player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );
    unawaited(_player.play());
    await done;
  }

  @override
  Future<void> stop() => _player.stop();
}
