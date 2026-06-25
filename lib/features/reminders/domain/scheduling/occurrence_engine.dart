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

  /// The NEXT batch to surface: the soonest upcoming occurrence plus any others
  /// firing the SAME evening (e.g. tonight could be Ashura + Al-Kahf together).
  /// Empty when nothing is upcoming.
  List<ReminderOccurrence> nextGroup(
    DateTime now, {
    int horizon = horizonDays,
    List<SunnahEvent>? events,
  }) {
    final all = upcoming(now, horizon: horizon, events: events);
    if (all.isEmpty) return const [];
    final first = all.first.fireAt;
    return all
        .where(
          (o) =>
              o.fireAt.year == first.year &&
              o.fireAt.month == first.month &&
              o.fireAt.day == first.day,
        )
        .toList();
  }

  static DateTime _evening(DateTime day) =>
      DateTime(day.year, day.month, day.day, fireHour, fireMinute);
}
