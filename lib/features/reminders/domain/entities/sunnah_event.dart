import '../../../../core/hijri/hijri_date.dart';

/// A Sunnah observance reminder, declared as DATA. To add a new reminder you
/// append one [SunnahEvent] to `sunnahEvents` (sunnah_events.dart) — there are no
/// switch arms or engine branches to touch. The pure engine just iterates the
/// registry and asks each event whether it falls on a given day.
class SunnahEvent {
  const SunnahEvent({
    required this.id,
    required this.idBase,
    required this.title,
    required this.body,
    required this.shortLabel,
    required this.occursOn,
    this.hijriLabel,
    this.occasion,
    this.fireSameDay = false,
    this.weekly = false,
    this.weeklyWeekday,
    this.opensAlKahf = false,
  });

  /// Stable key (notification payload / debugging).
  final String id;

  /// Notification-id base (kept 1000 apart per event; one-shots add the event's
  /// day-of-year so a rolling window never collides).
  final int idBase;

  final String title; // notification title
  final String body; // notification body
  final String shortLabel; // compact label for the list row

  /// Does this observance fall on [day] (whose Hijri date is [hijri])?
  final bool Function(DateTime day, HijriDate hijri) occursOn;

  /// Optional Hijri label for the row, e.g. "9 Muharram".
  final String Function(HijriDate hijri)? hijriLabel;

  /// Short occasion name for the "special date" gold pill on the Hijri date
  /// (e.g. "Ashura"). Distinct from the notification-framed [title]/[shortLabel].
  /// Null → not surfaced as a dated occasion (e.g. the weekly Al-Kahf nudge).
  final String? occasion;

  /// Fire on the observance day's evening (Al-Kahf) rather than the EVENING
  /// BEFORE (the default — gives fasting reminders their "…Tomorrow" framing).
  final bool fireSameDay;

  /// Recurring weekly (Al-Kahf): scheduled as a single repeating notification
  /// rather than enumerated one-shots.
  final bool weekly;
  final int? weeklyWeekday; // DateTime.monday … sunday (when [weekly])

  /// Tapping opens Surah Al-Kahf — the only actionable reminder in v1.
  final bool opensAlKahf;
}
