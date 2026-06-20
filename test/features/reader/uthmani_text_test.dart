import 'package:al_quran/features/reader/domain/uthmani_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('displayUthmani', () {
    test('inserts the elongation tatweel before a superscript-alef + maddah',
        () {
      // يَٰٓأَيُّهَا (no tatweel) → يَـٰٓأَيُّهَا (tatweel before ٰٓ)
      const input = 'يَٰٓأَيُّهَا';
      final out = displayUthmani(input);
      expect(out.contains('ـٰٓ'), isTrue);
      // every superscript-alef+maddah now carries a preceding tatweel
      expect('ٰٓ'.allMatches(out).length, 'ـٰٓ'.allMatches(out).length);
    });

    test('handles every occurrence in a word with two madds', () {
      const input = 'هَٰٓؤُلَٰٓءِ'; // contrived: two ٰٓ
      final out = displayUthmani(input);
      expect('ٰٓ'.allMatches(out).length, 2);
      expect('ـٰٓ'.allMatches(out).length, 2);
    });

    test('leaves waw/ya madds (maddah without superscript alef) untouched', () {
      const input = 'ءَامَنُوٓا'; // waw + maddah, no superscript alef
      final out = displayUthmani(input);
      expect(out.contains('ـ'), isFalse);
      expect(out, 'ءَامَنُوٓا');
    });

    test('strips the trailing end-of-ayah number marker', () {
      expect(displayUthmani('نص ١'), 'نص');
      expect(displayUthmani('نص ١٢٣'), 'نص');
    });

    test('does both: tatweel inserted and trailing marker stripped', () {
      final out = displayUthmani('يَٰٓأَيُّهَا ١');
      expect(out.endsWith('١'), isFalse);
      expect(out.contains('ـٰٓ'), isTrue);
    });
  });
}
