import 'sunnah_event.dart';

/// One concrete, dated firing of a [SunnahKind]. [eventDate] is the Gregorian
/// wall-date of the observance (shown on Home); [fireAt] is the local wall-clock
/// the notification fires (evening before, for the "…Tomorrow" framing).
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.kind,
    required this.eventDate,
    required this.fireAt,
    this.hijriLabel,
  });

  final SunnahKind kind;
  final DateTime eventDate;
  final DateTime fireAt;
  final String? hijriLabel; // e.g. "9 Muharram" — optional Home subtitle

  String get title => kind.title;
  String get body => kind.body;
  ReminderAction get action => kind.action;

  /// Deterministic per-occurrence id: kind base + the event's day-of-year (so a
  /// 120-day window of the same kind never collides). The weekly Al-Kahf is
  /// scheduled separately under [SunnahEventInfo.notificationIdBase] itself.
  int get notificationId =>
      kind.notificationIdBase +
      eventDate.difference(DateTime(eventDate.year)).inDays;
}
