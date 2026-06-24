/// The Sunnah observances v1 reminds about (local notifications only).
enum SunnahKind { alKahf, ayyamAlBid, ashura, arafah, firstTenDhulHijjah }

/// What tapping a notification does. v1: only Al-Kahf routes into the app.
enum ReminderAction { openSurahAlKahf, none }

/// Pure, static metadata per [SunnahKind] — the notification copy, the Home-row
/// label, the tap action, and a stable id base. One source of truth shared by
/// the scheduler, the Home section, and the tests. (Action-only bodies — no
/// virtue claims, per the owner.)
extension SunnahEventInfo on SunnahKind {
  /// Notification title.
  String get title => switch (this) {
        SunnahKind.alKahf => 'Read Surah Al-Kahf',
        SunnahKind.ayyamAlBid => 'The White Days Begin Tomorrow',
        SunnahKind.ashura => 'Fast Ashura Tomorrow',
        SunnahKind.arafah => 'Fast the Day of Arafah Tomorrow',
        SunnahKind.firstTenDhulHijjah => 'The Best 10 Days Begin Tomorrow',
      };

  /// Notification body.
  String get body => switch (this) {
        SunnahKind.alKahf =>
          "It's Thursday evening — read Surah Al-Kahf before Maghrib on Friday.",
        SunnahKind.ayyamAlBid => 'Fast the 13th, 14th & 15th — Ayyam al-Bid.',
        SunnahKind.ashura =>
          'Tomorrow is the 9th of Muharram — fast Ashura (the 9th & 10th).',
        SunnahKind.arafah => 'Tomorrow is the Day of Arafah (9 Dhul Hijjah).',
        SunnahKind.firstTenDhulHijjah =>
          'The first 10 days of Dhul Hijjah — increase good deeds, fasting & dhikr.',
      };

  /// Compact label for the Home "Upcoming Sunnah Reminders" list row.
  String get shortLabel => switch (this) {
        SunnahKind.alKahf => 'Read Surah Al-Kahf',
        SunnahKind.ayyamAlBid => 'White Days fast (13–15)',
        SunnahKind.ashura => 'Fast Ashura (9th & 10th)',
        SunnahKind.arafah => 'Fast the Day of Arafah',
        SunnahKind.firstTenDhulHijjah => 'First 10 days of Dhul Hijjah',
      };

  ReminderAction get action => this == SunnahKind.alKahf
      ? ReminderAction.openSurahAlKahf
      : ReminderAction.none;

  /// Stable notification-id base per kind (1000 apart). One-shot ids add the
  /// event's day-of-year (< 366) so a rolling window never collides; the weekly
  /// Al-Kahf uses the base itself.
  int get notificationIdBase => switch (this) {
        SunnahKind.alKahf => 1000,
        SunnahKind.ayyamAlBid => 2000,
        SunnahKind.ashura => 3000,
        SunnahKind.arafah => 4000,
        SunnahKind.firstTenDhulHijjah => 5000,
      };
}
