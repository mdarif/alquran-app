import '../../../../core/hijri/hijri_date.dart';
import '../entities/reminder_occurrence.dart';
import '../entities/sunnah_event.dart';

/// Computes upcoming Sunnah reminder occurrences from an injected `now` by
/// FORWARD-SCANNING Gregorian days and converting each via
/// [HijriDate.fromGregorian] (Gregorian→Hijri only — no inverse, no new
/// calendar engine). Pure & deterministic like `DailyPrayerTimes`: feed a fixed
/// clock in tests.
class OccurrenceEngine {
  const OccurrenceEngine();

  /// Local fire time for every reminder (the evening before → "…Tomorrow"; for
  /// Al-Kahf, the Thursday evening itself).
  static const int fireHour = 20;
  static const int fireMinute = 0;

  /// How far ahead to scan / schedule.
  static const int horizonDays = 120;

  /// All occurrences whose [ReminderOccurrence.fireAt] is at/after [now], within
  /// [horizon] days, sorted ascending. Includes the next concrete Al-Kahf
  /// Thursdays for the Home list (the scheduler registers Al-Kahf as a single
  /// weekly repeat, not as one-shots).
  List<ReminderOccurrence> upcoming(DateTime now, {int horizon = horizonDays}) {
    final today = DateTime(now.year, now.month, now.day);
    final out = <ReminderOccurrence>[];

    for (var i = 0; i <= horizon; i++) {
      final day = today.add(Duration(days: i));
      final h = HijriDate.fromGregorian(day);

      // Al-Kahf — Thursday evening (read Thu night → Fri before Maghrib).
      if (day.weekday == DateTime.thursday) {
        _add(
          out,
          now,
          SunnahKind.alKahf,
          eventDate: day,
          fireAt: _evening(day),
        );
      }
      // Ayyam al-Bid — one nudge on the eve of the 13th (covers 13–15).
      if (h.day == 13) {
        _add(
          out,
          now,
          SunnahKind.ayyamAlBid,
          eventDate: day,
          hijriLabel: '13 ${h.monthName}',
        );
      }
      // Ashura — eve of 9 Muharram (covers the 9th & 10th).
      if (h.month == 1 && h.day == 9) {
        _add(
          out,
          now,
          SunnahKind.ashura,
          eventDate: day,
          hijriLabel: '9 ${h.monthName}',
        );
      }
      // Day of Arafah — eve of 9 Dhul Hijjah.
      if (h.month == 12 && h.day == 9) {
        _add(
          out,
          now,
          SunnahKind.arafah,
          eventDate: day,
          hijriLabel: '9 ${h.monthName}',
        );
      }
      // First 10 of Dhul Hijjah — one nudge on the eve of the 1st.
      if (h.month == 12 && h.day == 1) {
        _add(
          out,
          now,
          SunnahKind.firstTenDhulHijjah,
          eventDate: day,
          hijriLabel: '1 ${h.monthName}',
        );
      }
    }

    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out;
  }

  /// Add an occurrence, defaulting its fire time to the EVE of [eventDate]
  /// (overridable for Al-Kahf, which fires on the day itself). Drops occurrences
  /// whose fire time has already passed.
  void _add(
    List<ReminderOccurrence> out,
    DateTime now,
    SunnahKind kind, {
    required DateTime eventDate,
    DateTime? fireAt,
    String? hijriLabel,
  }) {
    final at = fireAt ?? _evening(eventDate.subtract(const Duration(days: 1)));
    if (at.isBefore(now)) return;
    out.add(
      ReminderOccurrence(
        kind: kind,
        eventDate: eventDate,
        fireAt: at,
        hijriLabel: hijriLabel,
      ),
    );
  }

  static DateTime _evening(DateTime day) =>
      DateTime(day.year, day.month, day.day, fireHour, fireMinute);
}
