/// Pure helpers for translation-audio playback (a narrator reading a
/// translation aloud, distinct from Qur'an recitation). No plugin imports →
/// fully unit-testable (numbering canary in
/// `test/core/audio/translation_audio_source_test.dart`).
///
/// Addressed by `SSSAAA` (surah/ayah, zero-padded), NOT the global 1..6236 id
/// `recitation_source.dart` uses for Arabic recitation — the two numbering
/// schemes must never be conflated. See
/// `docs/translation-audio-chaining-plan.md` for the full design; the full
/// 6236-file Sahih International edition is live on R2 as of Phase 3, so
/// these helpers are valid for any surah/ayah, not just Al-Fatihah.
library;

/// `SSSAAA`: e.g. Fatiha 1:1 -> `001001`, Baqarah 2:1 -> `002001`.
String translationAudioKey({required int surah, required int ayah}) =>
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}';

/// Slug identifying the Sahih International translation-audio edition — used
/// both in the R2 URL and as the on-disk cache namespace, mirroring how
/// `recitation_source.dart` bakes the reciter into both. Baking it into the
/// path means a future translation-audio edition (Rowwad, etc. — Phase 4)
/// can never collide with this one's cached files.
const String _sahihInternationalSlug = 'en-sahih-international';

/// R2 bucket base, same custom domain the Arabic recitation audio uses
/// (`recitation_source.dart`'s `_audioBaseUrl`) — translation audio lives
/// under a **sibling** `translation-audio/` prefix, not nested under
/// `recitation/`, since a narrator reading a translation aloud is a distinct
/// thing from Qur'an recitation even though both share a bucket. Published
/// 2026-08-08 (Al-Fatihah's 7 files only so far — see
/// `../alquran-data/docs/translation-audio-r2-publish-plan.md`).
const String _audioBaseUrl = 'https://audio.alquranreader.com';

/// The Sahih International translation-audio URL for [surah]/[ayah].
///
/// R2 stores one MP3 per ayah, keyed `SSSAAA` (NOT the global 1..6236 id
/// `recitation_source.dart` uses) — see this file's doc comment for why the
/// two numbering schemes must never be conflated.
String translationAudioUrl({required int surah, required int ayah}) =>
    '$_audioBaseUrl/translation-audio/$_sahihInternationalSlug/'
    '${translationAudioKey(surah: surah, ayah: ayah)}.mp3';

/// Deterministic cache path (relative to the OS cache dir) for [surah]/[ayah]
/// — the SAME shape as `recitationCacheRelativePath`, so first play streams +
/// caches, replays resolve offline. Namespaced by the edition slug so it can
/// never collide with the Arabic recitation cache or a future translation
/// edition's cache.
String translationAudioCacheRelativePath({
  required int surah,
  required int ayah,
}) =>
    'translation-audio/$_sahihInternationalSlug/'
    '${translationAudioKey(surah: surah, ayah: ayah)}.mp3';

/// Text-translation resource slugs that have a matching translation-audio
/// track. Currently just Sahih International (`en-sahih-international` — see
/// `../alquran-data/config/sources.yaml`). Adding an audio-backed edition
/// later is a one-line addition here, not new UI code (mirrors how
/// `translation_audio_resources` is meant to work long-term — see the plan
/// doc's Data layer section).
const Set<String> translationAudioResourceSlugs = {'en-sahih-international'};

/// Whether any of the reader's currently-shown translation slugs has a
/// matching audio track. Gates the per-verse headphones affordance — it
/// would otherwise show for a reader with only e.g. Urdu/Hindi enabled, where
/// there is nothing for it to actually chain in.
bool hasAnyTranslationAudio(Iterable<String> shownResourceSlugs) =>
    shownResourceSlugs.any(translationAudioResourceSlugs.contains);
