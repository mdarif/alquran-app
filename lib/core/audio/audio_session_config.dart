import 'package:audio_session/audio_session.dart';

/// Configures the app's audio session once at startup so recitation plays through
/// the iOS silent switch and call interruptions auto-pause cleanly. Best-effort —
/// callers wrap in try/catch so it can never block launch. Kept tiny + plugin-only
/// (no just_audio) so `main.dart` can call it without pulling in the player.
Future<void> configureRecitationAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
}
