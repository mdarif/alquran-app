/// Pure helpers for translation-audio playback (a narrator reading a
/// translation aloud, distinct from Qur'an recitation). No plugin imports →
/// fully unit-testable (numbering canary in
/// `test/core/audio/translation_audio_source_test.dart`).
///
/// Addressed by `SSSAAA` (surah/ayah, zero-padded), NOT the global 1..6236 id
/// `recitation_source.dart` uses for Arabic recitation — the two numbering
/// schemes must never be conflated. See
/// `docs/translation-audio-chaining-plan.md` for the full design; this file
/// covers only the Al-Fatihah POC scope (Phase 2).
library;

/// `SSSAAA`: e.g. Fatiha 1:1 -> `001001`, Baqarah 2:1 -> `002001`.
String translationAudioKey({required int surah, required int ayah}) =>
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}';

/// Bundled local asset path for the Sahih International POC (Al-Fatihah only
/// — see `docs/dual-audio-urdu-poc-plan.md` Track 2 for the "local assets
/// first, no CDN dependency during app-level POC" precedent this follows).
/// General on purpose: the POC's asset bundle only contains Al-Fatihah's 7
/// files today, but the path shape doesn't need to change when it grows.
String sahihInternationalAssetPath({required int surah, required int ayah}) =>
    'assets/audio/poc/en-sahih-international/'
    '${translationAudioKey(surah: surah, ayah: ayah)}.mp3';

/// Whether [surah]/[ayah] is in the Al-Fatihah POC's scope. Gates the
/// translation-audio chain so it never fires outside the 7 bundled verses.
/// Al-Fatihah has exactly 7 ayahs — the upper bound matters as much as the
/// surah check, since a caller may pass a global recitation id as `ayah`
/// directly (see `AyahAudioCubit._inFatihaPocScope`'s POC-only shortcut).
bool isFatihaPocAyah({required int surah, required int ayah}) =>
    surah == 1 && ayah >= 1 && ayah <= 7;
