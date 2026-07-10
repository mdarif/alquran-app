/// Pure helpers that map a global ayah id (1..6236) to its recitation audio URL
/// and on-disk cache path. No plugin imports → fully unit-testable (the numbering
/// canary lives in `test/core/audio/recitation_source_test.dart`).
///
/// Reciter + bitrate are baked into both the URL path and the cache namespace so a
/// future reciter or bitrate can never collide with this one's cached files.
library;

/// Reciter Mishary Rashid Alafasy, 64 kbps mono — self-hosted on Cloudflare R2
/// (an infrastructure mirror, verse-by-verse), addressed by the global 1..6236
/// ayah id, the same index the bundled DB uses.
const String _cacheNamespace = 'alafasy_64';

/// R2 bucket base, fronted by a Cloudflare custom domain (edge-cached, range
/// requests + immutable cache headers). Files live at
/// `recitation/alafasy_64/{globalId}.mp3`. Point this at the R2 custom domain.
const String _audioBaseUrl = 'https://audio.alquranreader.com';

/// The recitation audio URL for a global ayah id.
///
/// R2 stores one MP3 per whole ayah, keyed by the SAME global 1..6236 index our DB
/// uses (Fatiha 1:1 = 1; 2:1 = 8; …), so `ayah.id` maps directly — no table.
String alafasyUrl(int ayahId) =>
    '$_audioBaseUrl/recitation/$_cacheNamespace/$ayahId.mp3';

/// Deterministic cache path (relative to the OS cache dir) for a global ayah id.
/// Same file on every replay → first play streams + caches, replays are offline.
String recitationCacheRelativePath(int ayahId) =>
    'recitation/$_cacheNamespace/$ayahId.mp3';
