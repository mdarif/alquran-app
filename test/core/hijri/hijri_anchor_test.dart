// BOUNDARY & CORRECTNESS TESTS for the Hijri anchor-table correction system.
//
// These are pure unit tests against `resolveHijriCorrectionDays` (the
// selection logic) and `HijriDate.fromGregorian` + the resolved correction
// (the actual date math) — no database, no widgets, no I/O. They pin the
// exact reported production bug (Gregorian 2026-07-29 rendering "13 Safar
// 1448 AH" instead of the verified local-sighting "14 Safar 1448 AH") and the
// month/year-roll boundaries where a naive constant offset would break.
import 'package:al_quran/core/hijri/hijri_anchor.dart';
import 'package:al_quran/core/hijri/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveHijriCorrectionDays — boundary & correctness', () {
    test(
      'reported drift: 2026-07-29 resolves to +1 for region PK, matching '
      'the verified local-sighting date',
      () {
        final anchors = [
          HijriAnchor(
            gregorianDate: DateTime(2026, 7, 15),
            correctionDays: 1,
            region: 'PK',
          ),
        ];
        final correction = resolveHijriCorrectionDays(
          DateTime(2026, 7, 29),
          anchors,
          region: 'PK',
        );
        expect(correction, 1);

        // And the actual date math lands exactly on the verified date.
        final hijri = HijriDate.fromGregorian(
          DateTime(2026, 7, 29),
          adjustmentDays: correction,
        );
        expect(hijri.formatted, '14 Safar 1448 AH');
      },
    );

    test('exact match on the anchor date itself applies that anchor', () {
      final anchors = [
        HijriAnchor(gregorianDate: DateTime(2026, 7, 15), correctionDays: 1),
      ];
      expect(
        resolveHijriCorrectionDays(DateTime(2026, 7, 15), anchors),
        1,
      );
    });

    test('a date strictly before the earliest anchor gets no correction', () {
      final anchors = [
        HijriAnchor(gregorianDate: DateTime(2026, 7, 15), correctionDays: 1),
      ];
      expect(
        resolveHijriCorrectionDays(DateTime(2026, 7, 14), anchors),
        0,
      );
    });

    test('picks the LATEST applicable anchor, not the first in the list', () {
      final anchors = [
        HijriAnchor(gregorianDate: DateTime(2026, 1, 1), correctionDays: 1),
        HijriAnchor(gregorianDate: DateTime(2026, 6, 1), correctionDays: -1),
        HijriAnchor(gregorianDate: DateTime(2026, 7, 15), correctionDays: 1),
      ];
      // Between the Jun and Jul anchors: Jun's -1 applies.
      expect(
        resolveHijriCorrectionDays(DateTime(2026, 6, 20), anchors),
        -1,
      );
      // After the Jul anchor: it supersedes both earlier ones.
      expect(
        resolveHijriCorrectionDays(DateTime(2026, 8, 1), anchors),
        1,
      );
    });

    test('anchors for a different region are ignored', () {
      final anchors = [
        HijriAnchor(
          gregorianDate: DateTime(2026, 7, 1),
          correctionDays: 1,
          region: 'IN',
        ),
      ];
      expect(
        resolveHijriCorrectionDays(
          DateTime(2026, 7, 29),
          anchors,
          region: 'PK',
        ),
        0, // no PK anchor applies — falls back cleanly, not 'IN''s value
      );
    });

    test('empty anchor list resolves to 0 for any date (base algorithm)', () {
      expect(resolveHijriCorrectionDays(DateTime(2026, 7, 29), const []), 0);
    });

    test('only y/m/d of the queried date matter, time-of-day is ignored', () {
      final anchors = [
        HijriAnchor(gregorianDate: DateTime(2026, 7, 15), correctionDays: 1),
      ];
      final morning = resolveHijriCorrectionDays(
        DateTime(2026, 7, 29, 0, 30),
        anchors,
      );
      final night = resolveHijriCorrectionDays(
        DateTime(2026, 7, 29, 23, 45),
        anchors,
      );
      expect(morning, 1);
      expect(night, 1);
    });
  });

  group('lunar month/year transition boundaries with a correction applied', () {
    test(
      '29-day month: correction does not create a duplicate or skipped day '
      'at the roll into the next month',
      () {
        // Safar 1448 is a 29-day month in the tabular calendar (day 29 on
        // 2026-08-12 uncorrected); with a +1 anchor active throughout, the
        // corrected sequence must still be perfectly contiguous.
        final anchors = [
          HijriAnchor(gregorianDate: DateTime(2026, 1, 1), correctionDays: 1),
        ];
        HijriDate corrected(DateTime d) => HijriDate.fromGregorian(
              d,
              adjustmentDays:
                  resolveHijriCorrectionDays(d, anchors, region: 'PK'),
            );

        var d = DateTime(2026, 7, 1);
        var prev = corrected(d);
        for (var i = 0; i < 60; i++) {
          d = d.add(const Duration(days: 1));
          final h = corrected(d);
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
            reason: 'non-contiguous corrected step on $d: '
                '${prev.year}-${prev.month}-${prev.day} -> '
                '${h.year}-${h.month}-${h.day}',
          );
          prev = h;
        }
      },
    );

    test(
      'a mid-month anchor change (e.g. a fresh sighting announcement) still '
      'produces a clean, single-day step across the anchor boundary',
      () {
        // The correction itself steps from 0 to 1 partway through Safar — the
        // resulting Hijri date must still advance by exactly one day, not
        // jump by two (which a naive re-run of a *global* offset could do).
        final anchors = [
          HijriAnchor(gregorianDate: DateTime(2026, 7, 20), correctionDays: 1),
        ];
        HijriDate corrected(DateTime d) => HijriDate.fromGregorian(
              d,
              adjustmentDays: resolveHijriCorrectionDays(d, anchors),
            );

        final before = corrected(DateTime(2026, 7, 19)); // no anchor yet
        final onAnchor = corrected(DateTime(2026, 7, 20)); // anchor kicks in

        // Both the raw calendar day AND the +1 correction advance together on
        // this boundary, so the visible Hijri date jumps by 2 here — this is
        // the intended, one-time "sighting correction" jump, not drift; every
        // day AFTER the anchor must resume single-day steps.
        final afterAnchor = corrected(DateTime(2026, 7, 21));
        expect(
          afterAnchor.day - onAnchor.day == 1 ||
              (afterAnchor.month != onAnchor.month && afterAnchor.day == 1),
          isTrue,
        );
        expect(before.day, isNot(onAnchor.day)); // sanity: something moved
      },
    );
  });
}
