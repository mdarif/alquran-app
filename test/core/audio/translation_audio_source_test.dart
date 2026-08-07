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

  group('sahihInternationalAssetPath', () {
    // POC scope is Al-Fatihah only (bundled local assets, no CDN yet — see
    // docs/translation-audio-chaining-plan.md Phase 2). The helper itself is
    // general so it doesn't need to change when the POC grows past Fatiha.
    test('builds the bundled asset path from surah/ayah', () {
      expect(
        sahihInternationalAssetPath(surah: 1, ayah: 1),
        'assets/audio/poc/en-sahih-international/001001.mp3',
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
        sahihInternationalAssetPath(surah: 2, ayah: 1),
        'assets/audio/poc/en-sahih-international/002001.mp3',
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
}
