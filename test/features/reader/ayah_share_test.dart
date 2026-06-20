import 'package:al_quran/features/reader/domain/ayah_share.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:flutter_test/flutter_test.dart';

const _urdu = TranslationResource(id: 1, languageCode: 'ur', name: 'Junagarhi');
const _english =
    TranslationResource(id: 3, languageCode: 'en', name: 'Hilali & Khan');

const _ayah = Ayah(
  id: 8,
  surahId: 2,
  ayahNumber: 1,
  textArabic: 'الٓمٓ',
  isSajda: false,
  translations: {1: 'الف لام میم', 3: 'Alif Lam Mim'},
);

void main() {
  group('languageName', () {
    test('maps known codes, upper-cases the rest', () {
      expect(languageName('ur'), 'Urdu');
      expect(languageName('en'), 'English');
      expect(languageName('hi'), 'Hindi');
      expect(languageName('fr'), 'FR');
    });
  });

  group('buildAyahShareText', () {
    test('includes Arabic, each translation, and a named reference', () {
      final text = buildAyahShareText(
        ayah: _ayah,
        resources: const [_urdu, _english],
        surahName: 'Al-Baqarah',
      );
      expect(
        text,
        'الٓمٓ\n\nالف لام میم\n\nAlif Lam Mim\n\n— Al-Baqarah 2:1',
      );
    });

    test('falls back to surahId:ayah when the name is unknown', () {
      final text = buildAyahShareText(ayah: _ayah, resources: const []);
      expect(text, 'الٓمٓ\n\n— 2:1');
    });

    test('omits translations the ayah does not have', () {
      const ayah = Ayah(
        id: 9,
        surahId: 2,
        ayahNumber: 2,
        textArabic: 'نص',
        isSajda: false,
        translations: {1: 'اردو'}, // no English
      );
      final text = buildAyahShareText(
        ayah: ayah,
        resources: const [_urdu, _english],
        surahName: 'Al-Baqarah',
      );
      expect(text, 'نص\n\nاردو\n\n— Al-Baqarah 2:2');
    });
  });
}
