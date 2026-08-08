import 'package:al_quran/core/audio/translation_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('translationAudioKey', () {
    test('formats surah/ayah as zero-padded SSSAAA', () {
      expect(translationAudioKey(surah: 1, ayah: 1), '001001');
      expect(translationAudioKey(surah: 2, ayah: 1), '002001');
      expect(translationAudioKey(surah: 114, ayah: 6), '114006');
    });
  });

  group('translationAudioUrl', () {
    // R2 publish (2026-08-08): al-quran-audio bucket, translation-audio/
    // prefix — sibling to recitation/, not nested under it. See
    // ../alquran-data/docs/translation-audio-r2-publish-plan.md.
    test('builds the R2 URL from surah/ayah', () {
      expect(
        translationAudioUrl(surah: 1, ayah: 1),
        'https://audio.alquranreader.com/translation-audio/'
        'en-sahih-international/001001.mp3',
      );
    });

    // Numbering canary, same reasoning as recitation_source_test.dart's:
    // Al-Fatihah's 7 verses precede Al-Baqarah, so 2:1 must NOT collide with
    // any Fatiha file. Distinct from the global 1..6236 id used by
    // recitation_source.dart — translation audio is addressed by SSSAAA, not
    // the global id, so these two numbering schemes must never be conflated.
    test('2:1 does not collide with any Al-Fatihah file', () {
      final fatihaKeys = [
        for (var a = 1; a <= 7; a++) translationAudioKey(surah: 1, ayah: a),
      ];
      expect(
        fatihaKeys,
        isNot(contains(translationAudioKey(surah: 2, ayah: 1))),
      );
      expect(
        translationAudioUrl(surah: 2, ayah: 1),
        'https://audio.alquranreader.com/translation-audio/'
        'en-sahih-international/002001.mp3',
      );
    });
  });

  group('translationAudioCacheRelativePath', () {
    test('builds a cache path namespaced by the edition slug', () {
      expect(
        translationAudioCacheRelativePath(surah: 1, ayah: 1),
        'translation-audio/en-sahih-international/001001.mp3',
      );
    });

    // Distinct namespace from the Arabic recitation cache
    // (recitation/alafasy_64/...) so the two can never collide on disk.
    test('cache path never collides with the recitation cache namespace', () {
      expect(
        translationAudioCacheRelativePath(surah: 1, ayah: 1),
        isNot(startsWith('recitation/')),
      );
    });
  });

  group('isFatihaPocAyah', () {
    test('true for surah 1, ayahs 1-7', () {
      expect(isFatihaPocAyah(surah: 1, ayah: 1), isTrue);
      expect(isFatihaPocAyah(surah: 1, ayah: 7), isTrue);
    });

    test('false for other surahs', () {
      expect(isFatihaPocAyah(surah: 2, ayah: 1), isFalse);
    });

    // Regression: the cubit's Fatiha-scope shortcut treats a global recitation
    // id 1-7 as "surah 1, ayah <id>" — an out-of-range ayah for surah 1 (which
    // only has 7) must NOT read as in-scope, or global id 8 (Baqarah 2:1) would
    // wrongly play Fatiha's translation audio.
    test('false for surah 1 beyond its 7 ayahs', () {
      expect(isFatihaPocAyah(surah: 1, ayah: 8), isFalse);
    });
  });

  group('hasAnyTranslationAudio', () {
    test('true when Sahih International is among the shown slugs', () {
      expect(
        hasAnyTranslationAudio(['ur-junagarhi', 'en-sahih-international']),
        isTrue,
      );
    });

    test('false when no shown slug has a translation-audio track', () {
      expect(
        hasAnyTranslationAudio(['ur-junagarhi', 'hi-tanzil']),
        isFalse,
      );
    });

    test('false for an empty selection', () {
      expect(hasAnyTranslationAudio(const []), isFalse);
    });
  });
}
