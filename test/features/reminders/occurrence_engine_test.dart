import 'package:al_quran/core/hijri/hijri_date.dart';
import 'package:al_quran/features/reminders/domain/entities/sunnah_event.dart';
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

  test('emits the near-term occurrences; far-off events stay out of the window',
      () {
    final kinds = engine.upcoming(now).map((o) => o.kind).toSet();
    expect(kinds, contains(SunnahKind.alKahf));
    expect(kinds, contains(SunnahKind.ashura)); // 9 Muharram is tomorrow
    expect(kinds, contains(SunnahKind.ayyamAlBid)); // 13 Muharram this month
    // Arafah / first-10 Dhul Hijjah are ~11 months out → beyond 120 days.
    expect(kinds, isNot(contains(SunnahKind.arafah)));
    expect(kinds, isNot(contains(SunnahKind.firstTenDhulHijjah)));
  });

  test('Ashura targets 9 Muharram and fires the evening before', () {
    final ashura =
        engine.upcoming(now).firstWhere((o) => o.kind == SunnahKind.ashura);
    final hd = HijriDate.fromGregorian(ashura.eventDate);
    expect((hd.month, hd.day), (1, 9));
    expect(ashura.fireAt, _eveOf(ashura.eventDate));
  });

  test('Ayyam al-Bid targets the 13th and fires the evening before', () {
    final wb =
        engine.upcoming(now).firstWhere((o) => o.kind == SunnahKind.ayyamAlBid);
    expect(HijriDate.fromGregorian(wb.eventDate).day, 13);
    expect(wb.fireAt, _eveOf(wb.eventDate));
  });

  test('Al-Kahf is a Thursday and fires that Thursday evening', () {
    final kahf =
        engine.upcoming(now).firstWhere((o) => o.kind == SunnahKind.alKahf);
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
    expect(occ.any((o) => o.kind == SunnahKind.ashura), isFalse);
    // Al-Kahf is still present (next Thursday is unaffected).
    expect(occ.any((o) => o.kind == SunnahKind.alKahf), isTrue);
  });

  test('one-shot notification ids are unique within the window', () {
    final ids = engine
        .upcoming(now)
        .where((o) => o.kind != SunnahKind.alKahf)
        .map((o) => o.notificationId)
        .toList();
    expect(ids.toSet().length, ids.length);
  });

  test('copy + action are wired per kind', () {
    expect(SunnahKind.alKahf.action, ReminderAction.openSurahAlKahf);
    expect(SunnahKind.ashura.action, ReminderAction.none);
    expect(SunnahKind.alKahf.title, 'Read Surah Al-Kahf');
    expect(SunnahKind.ashura.title, 'Fast Ashura Tomorrow');
  });
}
