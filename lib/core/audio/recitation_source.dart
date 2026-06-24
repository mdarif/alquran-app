/// Pure helpers that map a global ayah id (1..6236) to its recitation audio URL
/// and on-disk cache path. No plugin imports → fully unit-testable (the numbering
/// canary lives in `test/core/audio/recitation_source_test.dart`).
///
/// Reciter + bitrate are baked into both the URL and the cache path so a future
/// reciter or bitrate can never collide with this one's cached files.
library;

/// CDN reciter slug (islamic.network): Mishary Rashid Alafasy, 128 kbps.
const String _reciterSlug = 'ar.alafasy';
const int _bitrateKbps = 128;

/// Local cache namespace — mirrors the reciter+bitrate so it's self-describing.
const String _cacheNamespace = 'alafasy_128';

/// The recitation audio URL for a global ayah id.
///
/// islamic.network numbers audio by the SAME global 1..6236 ayah index our DB
/// uses (Fatiha 1:1 = 1; 2:1 = 8; …), so `ayah.id` maps directly — no table.
///
// NOTE: audio source licence UNVERIFIED — clear islamic.network's redistribution
// + on-device-caching terms (and any required in-app attribution: reciter Mishary
// Rashid Alafasy) before flipping FeatureFlags.audioRecitation for release.
String alafasyUrl(int ayahId) =>
    'https://cdn.islamic.network/quran/audio/$_bitrateKbps/$_reciterSlug/$ayahId.mp3';

/// Deterministic cache path (relative to the OS cache dir) for a global ayah id.
/// Same file on every replay → first play streams + caches, replays are offline.
String recitationCacheRelativePath(int ayahId) =>
    'recitation/$_cacheNamespace/$ayahId.mp3';
