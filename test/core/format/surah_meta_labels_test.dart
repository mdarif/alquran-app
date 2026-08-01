import 'package:al_quran/core/format/surah_meta_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('revelationLabel', () {
    test('maps the DB values (and their spelling variants)', () {
      expect(revelationLabel('makkah'), 'Makki');
      expect(revelationLabel('Mecca'), 'Makki');
      expect(revelationLabel('madinah'), 'Madani');
      expect(revelationLabel('MEDINA'), 'Madani');
    });

    test('is null for missing or unknown values', () {
      expect(revelationLabel(null), isNull);
      expect(revelationLabel(''), isNull);
      expect(revelationLabel('kufa'), isNull);
    });
  });

  group('ayahCountLabel', () {
    test('reads as "N Ayah" — uninflected, whatever the count', () {
      expect(ayahCountLabel(7), '7 Ayah');
      expect(ayahCountLabel(286), '286 Ayah');
      expect(ayahCountLabel(1), '1 Ayah');
    });

    test('is null when the count is unknown, so the segment is dropped', () {
      expect(ayahCountLabel(0), isNull);
      expect(ayahCountLabel(-1), isNull);
    });
  });
}
