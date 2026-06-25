import '../../../../core/hijri/hijri_date.dart';
import '../entities/reminder_occurrence.dart';
import '../entities/sunnah_event.dart';
import '../entities/sunnah_events.dart';

/// Computes upcoming Sunnah reminder occurrences from an injected `now` by
/// FORWARD-SCANNING Gregorian days and converting each via
/// [HijriDate.fromGregorian] (Gregorian→Hijri only — no inverse, no new calendar
/// engine). Data-driven: it just iterates the [sunnahEvents] registry and asks
/// each event whether it falls on the day. Pure & deterministic like
/// `DailyPrayerTimes` — feed a fixed clock in tests.
class OccurrenceEngine {
  const OccurrenceEngine();

  /// Local fire time for every reminder (the evening before → "…Tomorrow"; for a
  /// `fireSameDay` event like Al-Kahf, that day's own evening).
  static const int fireHour = 20;
  static const int fireMinute = 0;

  /// How far ahead to scan / schedule.
  static const int horizonDays = 120;

  /// All occurrences whose [ReminderOccurrence.fireAt] is at/after [now], within
  /// [horizon] days, sorted ascending. [events] defaults to the registry
  /// ([sunnahEvents]); inject a list in tests.
  List<ReminderOccurrence> upcoming(
    DateTime now, {
    int horizon = horizonDays,
    List<SunnahEvent>? events,
  }) {
    final defs = events ?? sunnahEvents;
    final today = DateTime(now.year, now.month, now.day);
    final out = <ReminderOccurrence>[];

    for (var i = 0; i <= horizon; i++) {
      final day = today.add(Duration(days: i));
      final h = HijriDate.fromGregorian(day);
      for (final e in defs) {
        if (!e.occursOn(day, h)) continue;
        final fireAt = e.fireSameDay
            ? _evening(day)
            : _evening(day.subtract(const Duration(days: 1)));
        if (fireAt.isBefore(now)) continue;
        out.add(
          ReminderOccurrence(
            event: e,
            eventDate: day,
            fireAt: fireAt,
            hijriLabel: e.hijriLabel?.call(h),
          ),
        );
      }
    }

    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out;
  }

  /// The reminders to SURFACE in the sheet — distinct from [upcoming], which is
  /// scheduling-oriented and drops a reminder the instant its night-before alarm
  /// time passes. This scans by event DAY (starting today) and never filters on
  /// [ReminderOccurrence.fireAt], so an event LINGERS through its own day: on the
  /// 10th of Muharram "Today is Ashura — fast it" stays on screen even though the
  /// alarm already fired the evening before. Weekly events (Al-Kahf) collapse to
  /// their nearest instance; soonest first, at most [limit].
  List<ReminderOccurrence> upNext(
    DateTime now, {
    int horizon = horizonDays,
    int limit = 5,
    List<SunnahEvent>? events,
  }) {
    final defs = events ?? sunnahEvents;
    final today = DateTime(now.year, now.month, now.day);
    final seen = <String>{};
    final out = <ReminderOccurrence>[];

    for (var i = 0; i <= horizon; i++) {
      final day = today.add(Duration(days: i));
      final h = HijriDate.fromGregorian(day);
      for (final e in defs) {
        if (!e.occursOn(day, h)) continue;
        if (!seen.add(e.id)) continue; // nearest instance per event only
        final fireAt = e.fireSameDay
            ? _evening(day)
            : _evening(day.subtract(const Duration(days: 1)));
        out.add(
          ReminderOccurrence(
            event: e,
            eventDate: day,
            fireAt: fireAt,
            hijriLabel: e.hijriLabel?.call(h),
          ),
        );
      }
    }

    out.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return out.take(limit).toList();
  }

  /// The dated Sunnah occasion falling on [day] (if any) — for the "special date"
  /// gold pill on the Hijri date. Reuses each event's [SunnahEvent.occursOn]
  /// against [day]'s Hijri date, so it shares one source of truth with the
  /// reminders. Weekly events (the Al-Kahf nudge) and events without an
  /// [SunnahEvent.occasion] name are skipped; returns the first match. Pure.
  SunnahEvent? occasionOn(DateTime day, {List<SunnahEvent>? events}) {
    final defs = events ?? sunnahEvents;
    final d = DateTime(day.year, day.month, day.day);
    final h = HijriDate.fromGregorian(d);
    for (final e in defs) {
      if (e.weekly || e.occasion == null) continue;
      if (e.occursOn(d, h)) return e;
    }
    return null;
  }

  static DateTime _evening(DateTime day) =>
      DateTime(day.year, day.month, day.day, fireHour, fireMinute);
}
