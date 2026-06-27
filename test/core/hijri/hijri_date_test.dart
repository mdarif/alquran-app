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

    test('a second anchor: 2026-06-25 → 9 Muharram 1448', () {
      // Cross-checks the converter at a different point (used by the reminder /
      // Sunnah-occasion tests: 9 Muharram = Ashura).
      final h = HijriDate.fromGregorian(DateTime(2026, 6, 25));
      expect((h.year, h.month, h.day), (1448, 1, 9));
    });

    test('consecutive Gregorian days advance the Hijri date by exactly one',
        () {
      // Stronger than the range check: every step must be CONTIGUOUS — +1 day,
      // or a clean month roll (prev day 29/30 → day 1 of the next month), or a
      // year roll (month 12 → month 1, year + 1). Catches any off-by-one or
      // skipped/repeated day at a month/year boundary.
      var d = DateTime(2026, 1, 1);
      var prev = HijriDate.fromGregorian(d);
      for (var i = 0; i < 400; i++) {
        d = d.add(const Duration(days: 1));
        final h = HijriDate.fromGregorian(d);
        final sameMonth = h.year == prev.year &&
            h.month == prev.month &&
            h.day == prev.day + 1;
        final monthRoll = h.year == prev.year &&
            h.month == prev.month + 1 &&
            h.day == 1 &&
            (prev.day == 29 || prev.day == 30);
        final yearRoll = h.year == prev.year + 1 &&
            prev.month == 12 &&
            h.month == 1 &&
            h.day == 1 &&
            (prev.day == 29 || prev.day == 30);
        expect(
          sameMonth || monthRoll || yearRoll,
          isTrue,
          reason: 'non-contiguous Hijri step on $d: '
              '${prev.year}-${prev.month}-${prev.day} -> '
              '${h.year}-${h.month}-${h.day}',
        );
        prev = h;
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
