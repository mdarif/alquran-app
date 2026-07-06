import 'package:al_quran/core/hijri/hijri_date.dart';
import 'package:al_quran/features/reminders/domain/entities/sunnah_event.dart';
import 'package:al_quran/features/reminders/domain/entities/sunnah_events.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the SHIPPED Sunnah catalog itself — the actual date rules a wrong
/// `occursOn`/`idBase` would silently ship. Each event's predicate is exercised
/// directly with a constructed HijriDate, so no Gregorian→Hijri anchoring is
/// needed. (The engine that schedules from these is covered separately.)
void main() {
  SunnahEvent event(String id) => sunnahEvents.firstWhere((e) => e.id == id);

  // A concrete Gregorian day of a given weekday (the al-Kahf rule is weekday-,
  // not Hijri-based). Hijri part is irrelevant for it, so a dummy date is fine.
  DateTime dayOfWeek(int weekday) {
    var d = DateTime(2026, 1, 1);
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // The Hijri-based predicates ignore the Gregorian arg, so any concrete day
  // stands in for it.
  final anyGregorian = DateTime(2026, 1, 1);
  HijriDate hijri(int month, int day) =>
      HijriDate(year: 1447, month: month, day: day);

  test('catalog is internally consistent (unique ids and idBases)', () {
    final ids = sunnahEvents.map((e) => e.id).toList();
    final bases = sunnahEvents.map((e) => e.idBase).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'ids must be unique');
    expect(
      bases.toSet(),
      hasLength(bases.length),
      reason: 'idBases must be unique (they namespace notification ids)',
    );
  });

  test('Al-Kahf fires on Thursday only (weekly, same-day evening)', () {
    final alKahf = event('al_kahf');
    expect(alKahf.occursOn(dayOfWeek(DateTime.thursday), hijri(3, 7)), isTrue);
    expect(alKahf.occursOn(dayOfWeek(DateTime.friday), hijri(3, 7)), isFalse);
    expect(alKahf.weekly, isTrue);
    expect(alKahf.weeklyWeekday, DateTime.thursday);
    expect(alKahf.fireSameDay, isTrue);
    expect(alKahf.opensAlKahf, isTrue);
  });

  test('the White Days begin on the 13th of any month', () {
    final wb = event('ayyam_al_bid');
    expect(wb.occursOn(anyGregorian, hijri(3, 13)), isTrue);
    expect(wb.occursOn(anyGregorian, hijri(9, 13)), isTrue); // any month
    expect(wb.occursOn(anyGregorian, hijri(3, 12)), isFalse);
    expect(wb.occursOn(anyGregorian, hijri(3, 14)), isFalse);
    expect(wb.occasion, 'Ayyam al-Bid');
  });

  test('Ashura is a two-day pair: 9th and 10th of Muharram', () {
    expect(event('ashura').occursOn(anyGregorian, hijri(1, 9)), isTrue);
    expect(event('ashura').occursOn(anyGregorian, hijri(1, 10)), isFalse);
    expect(event('ashura_day').occursOn(anyGregorian, hijri(1, 10)), isTrue);
    expect(event('ashura_day').occursOn(anyGregorian, hijri(1, 9)), isFalse);
    // Only in Muharram (month 1), not the same day number in another month.
    expect(event('ashura').occursOn(anyGregorian, hijri(2, 9)), isFalse);
  });

  test('Arafah is 9 Dhul Hijjah; the best-10 opens on 1 Dhul Hijjah', () {
    expect(event('arafah').occursOn(anyGregorian, hijri(12, 9)), isTrue);
    expect(event('arafah').occursOn(anyGregorian, hijri(12, 8)), isFalse);
    expect(
      event('first_ten_dhul_hijjah').occursOn(anyGregorian, hijri(12, 1)),
      isTrue,
    );
    expect(
      event('first_ten_dhul_hijjah').occursOn(anyGregorian, hijri(12, 2)),
      isFalse,
    );
  });
}
