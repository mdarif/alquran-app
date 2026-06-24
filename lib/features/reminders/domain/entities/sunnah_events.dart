import 'sunnah_event.dart';

/// The Sunnah reminders, declared as data (action-only copy — no virtue claims).
///
/// ───────────────────────────────────────────────────────────────────────────
/// TO ADD A NEW REMINDER: append one [SunnahEvent] below.
///  • pick a unique `id` and an `idBase` 1000 above the last one;
///  • `occursOn` decides the day — use `hijri.month`/`hijri.day` for Hijri dates
///    (e.g. `(d, h) => h.month == 7 && h.day == 27` for 27 Rajab) or `day.weekday`
///    for weekday-based ones;
///  • by default it fires 20:00 the EVENING BEFORE (the "…Tomorrow" framing).
///    Set `fireSameDay: true` to fire on the day's own evening, or `weekly: true`
///    (+ `weeklyWeekday`) for a recurring weekly nudge.
/// That's it — no other file changes.
/// ───────────────────────────────────────────────────────────────────────────
final List<SunnahEvent> sunnahEvents = [
  SunnahEvent(
    id: 'al_kahf',
    idBase: 1000,
    title: 'Read Surah Al-Kahf',
    body:
        "It's Thursday evening — read Surah Al-Kahf before Maghrib on Friday.",
    shortLabel: 'Read Surah Al-Kahf',
    occursOn: (day, h) => day.weekday == DateTime.thursday,
    fireSameDay: true,
    weekly: true,
    weeklyWeekday: DateTime.thursday,
    opensAlKahf: true,
  ),
  SunnahEvent(
    id: 'ayyam_al_bid',
    idBase: 2000,
    title: 'The White Days Begin Tomorrow',
    body: 'Fast the 13th, 14th & 15th — Ayyam al-Bid.',
    shortLabel: 'White Days fast (13–15)',
    occursOn: (day, h) => h.day == 13,
    hijriLabel: (h) => '13 ${h.monthName}',
  ),
  SunnahEvent(
    id: 'ashura',
    idBase: 3000,
    title: 'Fast Ashura Tomorrow',
    body: 'Tomorrow is the 9th of Muharram — fast Ashura (the 9th & 10th).',
    shortLabel: 'Fast Ashura (9th & 10th)',
    occursOn: (day, h) => h.month == 1 && h.day == 9,
    hijriLabel: (h) => '9 ${h.monthName}',
  ),
  SunnahEvent(
    id: 'arafah',
    idBase: 4000,
    title: 'Fast the Day of Arafah Tomorrow',
    body: 'Tomorrow is the Day of Arafah (9 Dhul Hijjah).',
    shortLabel: 'Fast the Day of Arafah',
    occursOn: (day, h) => h.month == 12 && h.day == 9,
    hijriLabel: (h) => '9 ${h.monthName}',
  ),
  SunnahEvent(
    id: 'first_ten_dhul_hijjah',
    idBase: 5000,
    title: 'The Best 10 Days Begin Tomorrow',
    body:
        'The first 10 days of Dhul Hijjah — increase good deeds, fasting & dhikr.',
    shortLabel: 'First 10 days of Dhul Hijjah',
    occursOn: (day, h) => h.month == 12 && h.day == 1,
    hijriLabel: (h) => '1 ${h.monthName}',
  ),
];
