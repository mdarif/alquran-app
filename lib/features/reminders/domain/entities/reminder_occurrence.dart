import 'sunnah_event.dart';

/// One concrete, dated firing of a [SunnahEvent]. [eventDate] is the Gregorian
/// wall-date of the observance (shown in the list); [fireAt] is the local
/// wall-clock the notification fires.
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.event,
    required this.eventDate,
    required this.fireAt,
    this.hijriLabel,
  });

  final SunnahEvent event;
  final DateTime eventDate;
  final DateTime fireAt;
  final String? hijriLabel; // e.g. "9 Muharram" — optional row subtitle

  String get title => event.title;
  String get body => event.body;
  String get shortLabel => event.shortLabel;
  bool get opensAlKahf => event.opensAlKahf;

  /// Deterministic per-occurrence id: event base + the event's day-of-year (so a
  /// 120-day window of the same event never collides). Weekly events are
  /// scheduled separately under [SunnahEvent.idBase] itself.
  int get notificationId =>
      event.idBase + eventDate.difference(DateTime(eventDate.year)).inDays;
}
