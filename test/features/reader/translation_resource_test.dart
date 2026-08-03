import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:flutter_test/flutter_test.dart';

/// displayCredit is the single, data-driven fallback chain the reader and the
/// Translations picker both use for a one-line credit: creditName (when the
/// author field is a multi-person licensing credit too long to show inline),
/// else author, else name. No slug ever appears in the logic — the DB's
/// resources.credit_name column is the only thing that can trigger the swap.
void main() {
  group('TranslationResource.displayCredit', () {
    test('uses creditName when present, even though author is also set', () {
      const resource = TranslationResource(
        id: 1,
        slug: 'ur-roman-abu-rayyan',
        languageCode: 'ur',
        name: 'Abu Rayyan',
        author: 'Muhammad Junagarhi; transliterated by Abu Rayyan',
        creditName: 'Abu Rayyan',
      );
      expect(resource.displayCredit, 'Abu Rayyan');
    });

    test('falls back to author when creditName is null', () {
      const resource = TranslationResource(
        id: 2,
        slug: 'hi-ahsanul-kalam',
        languageCode: 'hi',
        name: 'Ahsanul Kalam',
        author: 'Shaikh Muhammad Rais Qureshi',
      );
      expect(resource.displayCredit, 'Shaikh Muhammad Rais Qureshi');
    });

    test('falls back to author when creditName is blank', () {
      const resource = TranslationResource(
        id: 3,
        slug: 'hi-ahsanul-kalam',
        languageCode: 'hi',
        name: 'Ahsanul Kalam',
        author: 'Shaikh Muhammad Rais Qureshi',
        creditName: '   ',
      );
      expect(resource.displayCredit, 'Shaikh Muhammad Rais Qureshi');
    });

    test('falls back to name when both creditName and author are absent', () {
      const resource = TranslationResource(
        id: 4,
        slug: 'en-sahih-international',
        languageCode: 'en',
        name: 'Sahih International',
      );
      expect(resource.displayCredit, 'Sahih International');
    });

    test('experimental defaults to false and reads back what is set', () {
      const plain = TranslationResource(
        id: 5,
        slug: 'en-sahih-international',
        languageCode: 'en',
        name: 'Sahih International',
      );
      const pilot = TranslationResource(
        id: 6,
        slug: 'ur-roman-abu-rayyan',
        languageCode: 'ur',
        name: 'Abu Rayyan',
        experimental: true,
      );
      expect(plain.experimental, isFalse);
      expect(pilot.experimental, isTrue);
    });
  });
}
