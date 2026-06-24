import 'package:al_quran/core/hijri/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HijriDate.fromGregorian (tabular)', () {
    test('a well-known anchor: 2000-01-01 → 24 Ramadan 1420', () {
      final h = HijriDate.fromGregorian(DateTime(2000, 1, 1));
      expect((h.year, h.month, h.day), (1420, 9, 24));
    });

    test('adjustmentDays shifts the date (+1 → next Hijri day)', () {
      final h =
          HijriDate.fromGregorian(DateTime(2000, 1, 1), adjustmentDays: 1);
      expect((h.year, h.month, h.day), (1420, 9, 25));
      final back =
          HijriDate.fromGregorian(DateTime(2000, 1, 1), adjustmentDays: -1);
      expect((back.year, back.month, back.day), (1420, 9, 23));
    });

    test('only the y/m/d of the DateTime matter (time of day is ignored)', () {
      final a = HijriDate.fromGregorian(DateTime(2026, 6, 24, 2));
      final b = HijriDate.fromGregorian(DateTime(2026, 6, 24, 23, 59));
      expect((a.year, a.month, a.day), (b.year, b.month, b.day));
    });

    test('month/day stay in valid Hijri ranges across a year of dates', () {
      var d = DateTime(2026, 1, 1);
      for (var i = 0; i < 365; i++) {
        final h = HijriDate.fromGregorian(d);
        expect(h.month, inInclusiveRange(1, 12));
        expect(h.day, inInclusiveRange(1, 30));
        d = d.add(const Duration(days: 1));
      }
    });
  });

  group('English rendering', () {
    test('formatted: day · month · year · the AH marker', () {
      final h =
          HijriDate.fromGregorian(DateTime(2000, 1, 1)); // 24 Ramadan 1420
      expect(h.formatted, '24 Ramadan 1420 AH');
    });

    test('the day is zero-padded to two digits', () {
      const h = HijriDate(year: 1448, month: 1, day: 7);
      expect(h.formatted, '07 Muharram 1448 AH');
      expect(h.monthName, 'Muharram');
    });
  });
}
