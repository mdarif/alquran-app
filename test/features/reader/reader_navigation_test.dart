import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/reader_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

List<Ayah> _pagedAyahs(List<int> pages) => [
      for (var i = 0; i < pages.length; i++)
        Ayah(
          id: i + 1,
          surahId: 2,
          ayahNumber: i + 1,
          textArabic: '0123456789', // equal length so fractions are even
          isSajda: false,
          page: pages[i],
        ),
    ];

const _headings = {
  1: SurahHeading(number: 1, nameEnglish: 'Al-Fatihah', totalAyahs: 7),
  2: SurahHeading(number: 2, nameEnglish: 'Al-Baqarah', totalAyahs: 286),
  3: SurahHeading(number: 3, nameEnglish: 'Ali Imran', totalAyahs: 200),
};

void main() {
  group('ReaderDimensionRange.count', () {
    test('matches the mushaf-wide totals', () {
      expect(ReaderDimension.surah.count, 114);
      expect(ReaderDimension.juz.count, 30);
      expect(ReaderDimension.hizb.count, 60);
      expect(ReaderDimension.page.count, 604);
      expect(ReaderDimension.ruku.count, 558);
    });
  });

  group('adjacentTarget — surah', () {
    test('next resolves the English name from headings', () {
      final next = adjacentTarget(
        const ReaderTarget.surah(2, 'Al-Baqarah'),
        1,
        _headings,
      );
      expect(next, const ReaderTarget.surah(3, 'Ali Imran'));
    });

    test('previous resolves the English name from headings', () {
      final prev = adjacentTarget(
        const ReaderTarget.surah(2, 'Al-Baqarah'),
        -1,
        _headings,
      );
      expect(prev, const ReaderTarget.surah(1, 'Al-Fatihah'));
    });

    test('falls back to "Surah N" when the heading is missing', () {
      final next = adjacentTarget(
        const ReaderTarget.surah(3, 'Ali Imran'),
        1,
        _headings, // no heading for 4
      );
      expect(next, const ReaderTarget.surah(4, 'Surah 4'));
    });

    test('previous from the first surah is null (no wrap)', () {
      expect(
        adjacentTarget(
          const ReaderTarget.surah(1, 'Al-Fatihah'),
          -1,
          _headings,
        ),
        isNull,
      );
    });

    test('next from the last surah is null (no wrap)', () {
      expect(
        adjacentTarget(const ReaderTarget.surah(114, 'An-Nas'), 1, _headings),
        isNull,
      );
    });
  });

  group('adjacentTarget — index dimensions', () {
    test('juz next/previous in range', () {
      expect(
        adjacentTarget(const ReaderTarget.juz(5), 1, _headings),
        const ReaderTarget.juz(6),
      );
      expect(
        adjacentTarget(const ReaderTarget.juz(5), -1, _headings),
        const ReaderTarget.juz(4),
      );
    });

    test('juz bounds (1 and 30) clamp to null', () {
      expect(adjacentTarget(const ReaderTarget.juz(1), -1, _headings), isNull);
      expect(adjacentTarget(const ReaderTarget.juz(30), 1, _headings), isNull);
    });

    test('hizb bounds (1 and 60)', () {
      expect(adjacentTarget(const ReaderTarget.hizb(1), -1, _headings), isNull);
      expect(adjacentTarget(const ReaderTarget.hizb(60), 1, _headings), isNull);
      expect(
        adjacentTarget(const ReaderTarget.hizb(59), 1, _headings),
        const ReaderTarget.hizb(60),
      );
    });

    test('page bounds (1 and 604)', () {
      expect(adjacentTarget(const ReaderTarget.page(1), -1, _headings), isNull);
      expect(
        adjacentTarget(const ReaderTarget.page(604), 1, _headings),
        isNull,
      );
      expect(
        adjacentTarget(const ReaderTarget.page(603), 1, _headings),
        const ReaderTarget.page(604),
      );
    });

    test('ruku bounds (1 and 558)', () {
      expect(adjacentTarget(const ReaderTarget.ruku(1), -1, _headings), isNull);
      expect(
        adjacentTarget(const ReaderTarget.ruku(558), 1, _headings),
        isNull,
      );
    });
  });

  group('pageAtFraction', () {
    test('returns null for an empty section', () {
      expect(pageAtFraction(const [], 0.5), isNull);
    });

    test('maps the top of the scroll to the first page', () {
      expect(pageAtFraction(_pagedAyahs([1, 2, 3]), 0), 1);
    });

    test('maps the bottom of the scroll to the last page', () {
      expect(pageAtFraction(_pagedAyahs([1, 2, 3]), 1), 3);
    });

    test('maps the middle to a middle page', () {
      expect(pageAtFraction(_pagedAyahs([1, 2, 3]), 0.5), 2);
    });

    test('clamps out-of-range fractions', () {
      final ayahs = _pagedAyahs([4, 5, 6]);
      expect(pageAtFraction(ayahs, -1), 4);
      expect(pageAtFraction(ayahs, 2), 6);
    });
  });

  group('adjacentTarget — edge deltas', () {
    test('delta 0 stays on the same section', () {
      expect(
        adjacentTarget(const ReaderTarget.juz(5), 0, _headings),
        const ReaderTarget.juz(5),
      );
    });

    test('delta that overshoots the upper bound is null', () {
      expect(adjacentTarget(const ReaderTarget.juz(29), 5, _headings), isNull);
    });
  });
}
