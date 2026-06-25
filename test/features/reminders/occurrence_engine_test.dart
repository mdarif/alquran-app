import 'package:al_quran/core/hijri/hijri_date.dart';
import 'package:al_quran/features/reminders/domain/scheduling/occurrence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// The evening (20:00) of the day BEFORE [d] — the eve-before fire time.
DateTime _eveOf(DateTime d) {
  final prev =
      DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1));
  return DateTime(prev.year, prev.month, prev.day, 20);
}

void main() {
  const engine = OccurrenceEngine();
  // 2026-06-24 is 8 Muharram 1448 (per the tabular converter), 10:00 local.
  final now = DateTime(2026, 6, 24, 10);

  test('emits the near-term events; far-off ones stay out of the window', () {
    final ids = engine.upcoming(now).map((o) => o.event.id).toSet();
    expect(ids, contains('al_kahf'));
    expect(ids, contains('ashura')); // 9 Muharram is tomorrow
    expect(ids, contains('ayyam_al_bid')); // 13 Muharram this month
    // Arafah / first-10 Dhul Hijjah are ~11 months out → beyond 120 days.
    expect(ids, isNot(contains('arafah')));
    expect(ids, isNot(contains('first_ten_dhul_hijjah')));
  });

  test('Ashura targets 9 Muharram and fires the evening before', () {
    final ashura =
        engine.upcoming(now).firstWhere((o) => o.event.id == 'ashura');
    final hd = HijriDate.fromGregorian(ashura.eventDate);
    expect((hd.month, hd.day), (1, 9));
    expect(ashura.fireAt, _eveOf(ashura.eventDate));
  });

  test('Ayyam al-Bid targets the 13th and fires the evening before', () {
    final wb =
        engine.upcoming(now).firstWhere((o) => o.event.id == 'ayyam_al_bid');
    expect(HijriDate.fromGregorian(wb.eventDate).day, 13);
    expect(wb.fireAt, _eveOf(wb.eventDate));
  });

  test('Al-Kahf is a Thursday and fires that Thursday evening (fireSameDay)',
      () {
    final kahf =
        engine.upcoming(now).firstWhere((o) => o.event.id == 'al_kahf');
    expect(kahf.eventDate.weekday, DateTime.thursday);
    expect(
      kahf.fireAt,
      DateTime(
        kahf.eventDate.year,
        kahf.eventDate.month,
        kahf.eventDate.day,
        20,
      ),
    );
    expect(kahf.opensAlKahf, isTrue);
  });

  test('results are sorted by fireAt and never in the past', () {
    final occ = engine.upcoming(now);
    for (var i = 1; i < occ.length; i++) {
      expect(occ[i].fireAt.isBefore(occ[i - 1].fireAt), isFalse);
    }
    for (final o in occ) {
      expect(o.fireAt.isBefore(now), isFalse);
    }
  });

  test('drops an occurrence whose fire time has already passed', () {
    // 21:00 is past Ashura's 20:00 eve fire; the next Ashura is ~a year out.
    final later = DateTime(2026, 6, 24, 21);
    final occ = engine.upcoming(later);
    expect(occ.any((o) => o.event.id == 'ashura'), isFalse);
    // Al-Kahf is still present (next Thursday is unaffected).
    expect(occ.any((o) => o.event.id == 'al_kahf'), isTrue);
  });

  test('one-shot (non-weekly) notification ids are unique in the window', () {
    final ids = engine
        .upcoming(now)
        .where((o) => !o.event.weekly)
        .map((o) => o.notificationId)
        .toList();
    expect(ids.toSet().length, ids.length);
  });

  group('occasionOn (special-date pill)', () {
    test('9 Muharram resolves to Ashura', () {
      // 2026-06-25 is 9 Muharram — and also a Thursday, so this doubly proves
      // the weekly Al-Kahf is excluded in favour of the dated Ashura.
      final e = engine.occasionOn(DateTime(2026, 6, 25));
      expect(e?.id, 'ashura');
      expect(e?.occasion, 'Ashura');
    });

    test('an ordinary day resolves to null', () {
      // 2026-06-24 is 8 Muharram — no dated occasion.
      expect(engine.occasionOn(DateTime(2026, 6, 24, 10)), isNull);
    });

    test('a plain Thursday resolves to null (weekly Al-Kahf excluded)', () {
      // 2026-07-02 is a Thursday but ~16 Muharram — no dated occasion.
      final day = DateTime(2026, 7, 2);
      expect(day.weekday, DateTime.thursday);
      expect(engine.occasionOn(day), isNull);
    });
  });
}
