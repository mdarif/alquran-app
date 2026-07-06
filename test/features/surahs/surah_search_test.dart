import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/surah_search.dart';
import 'package:flutter_test/flutter_test.dart';

// A handful of real surahs spanning the matcher's cases (al- prefix, hyphen,
// apostrophe, a name that is a substring of another, distinct numbers).
Surah _s(int id, String ar, String en, int total) =>
    Surah(id: id, nameArabic: ar, nameEnglish: en, totalAyahs: total);

final _surahs = <Surah>[
  _s(1, 'الفاتحة', 'Al-Fatihah', 7),
  _s(2, 'البقرة', 'Al-Baqarah', 286),
  _s(18, 'الكهف', 'Al-Kahf', 110),
  _s(36, 'يس', 'Ya-Sin', 83),
  _s(67, 'الملك', 'Al-Mulk', 30),
  _s(112, 'الإخلاص', 'Al-Ikhlas', 4),
];

List<int> _ids(String q) => filterSurahs(_surahs, q).map((s) => s.id).toList();

void main() {
  group('filterSurahs', () {
    test('blank query returns the full list in id order', () {
      expect(_ids(''), [1, 2, 18, 36, 67, 112]);
      expect(_ids('   '), [1, 2, 18, 36, 67, 112]);
    });

    test('English name matches, tolerant of the leading "Al-"', () {
      expect(_ids('kahf').first, 18);
      expect(_ids('mulk').first, 67);
      expect(_ids('baqara').first, 2); // partial, no trailing h
    });

    test('best match ranks first (exact/prefix over substring)', () {
      // "al" prefixes several; exact-ish names still surface, Al-Fatihah included.
      final r = _ids('fatiha');
      expect(r.first, 1);
    });

    test('hyphen/spacing is ignored — "yasin" finds Ya-Sin', () {
      expect(_ids('yasin'), [36]);
      expect(_ids('ya sin'), [36]);
    });

    test('a lone number is a surah number (exact ranks first)', () {
      expect(_ids('36'), [36]);
      expect(_ids('1').first, 1); // "1" → 1, then 18, 112 (id starts with 1)
      expect(_ids('67'), [67]);
    });

    test('Arabic query matches the Arabic name', () {
      expect(_ids('الكهف'), [18]);
      expect(_ids('يس'), [36]);
    });

    test('gibberish matches nothing', () {
      expect(_ids('zzzzz'), isEmpty);
    });
  });

  group('searchSurahs — verse references', () {
    // (surahId, verse?) for the first hit.
    (int, int?) first(String q) {
      final h = searchSurahs(_surahs, q).first;
      return (h.surah.id, h.verse);
    }

    test('compact "18:5" and "18.5" resolve to surah 18, verse 5', () {
      expect(first('18:5'), (18, 5));
      expect(first('18.5'), (18, 5));
      expect(searchSurahs(_surahs, '18:5'), hasLength(1));
    });

    test('natural "surah 15 ... verse 5" style — number + verse', () {
      // (67 is the only surah with >5 ayahs among a name-free number query)
      expect(first('surah 67 verse 5'), (67, 5));
      expect(first('67 ayah 5'), (67, 5));
    });

    test('name + trailing number → that surah, that verse', () {
      expect(first('kahf 5'), (18, 5));
      expect(first('mulk 10'), (67, 10));
    });

    test('a verse past the surah length is dropped (opens at the top)', () {
      expect(first('18:500'), (18, null)); // Al-Kahf has 110
      expect(first('ikhlas 9'), (112, null)); // Al-Ikhlas has 4
    });

    test('a plain name still has no verse', () {
      expect(first('kahf'), (18, null));
    });

    test('an unknown surah number in a ref yields nothing', () {
      expect(searchSurahs(_surahs, '99:1'), isEmpty); // 99 not in fixture
    });
  });

  group('globalAyahId', () {
    // Cumulative: id = sum(totalAyahs before) + verse.
    final all = [
      _n(1, 7),
      _n(2, 286),
      _n(3, 200),
    ];
    test('sums preceding surahs then adds the verse', () {
      expect(globalAyahId(all, 1, 1), 1);
      expect(globalAyahId(all, 1, 7), 7);
      expect(globalAyahId(all, 2, 1), 8);
      expect(globalAyahId(all, 3, 5), 7 + 286 + 5);
    });
  });
}

Surah _n(int id, int total) =>
    Surah(id: id, nameArabic: '?', nameEnglish: '?', totalAyahs: total);
