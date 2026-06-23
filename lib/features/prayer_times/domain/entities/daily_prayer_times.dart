import 'forbidden_window.dart';
import 'geo_location.dart';
import 'prayer.dart';

/// One day's prayer schedule for a [location], as **local** DateTimes. Pure value
/// object — the next-prayer and current-period queries are plain functions over
/// the stored times, so they're trivially testable with a fixed `now`.
class DailyPrayerTimes {
  const DailyPrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.location,
    required this.date,
  });

  final DateTime fajr;
  final DateTime sunrise; // not a salah — bounds the Fajr light phase only
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final GeoLocation location;
  final DateTime date;

  /// The five obligatory prayers in order (sunrise omitted).
  List<(Prayer, DateTime)> get schedule => [
        (Prayer.fajr, fajr),
        (Prayer.dhuhr, dhuhr),
        (Prayer.asr, asr),
        (Prayer.maghrib, maghrib),
        (Prayer.isha, isha),
      ];

  /// The chronological "next event" sequence — the five salah plus Sunrise.
  /// Sunrise bounds the Fajr window: between Fajr and sunrise the meaningful
  /// upcoming marker is Sunrise (when Fajr time expires), not Dhuhr; after
  /// sunrise it's Dhuhr.
  List<(Prayer, DateTime)> get _markers => [
        (Prayer.fajr, fajr),
        (Prayer.sunrise, sunrise),
        (Prayer.dhuhr, dhuhr),
        (Prayer.asr, asr),
        (Prayer.maghrib, maghrib),
        (Prayer.isha, isha),
      ];

  /// The next marker strictly after [now] — a salah, or Sunrise during the dawn
  /// (post-Fajr) window. Null once Isha has passed (the caller then recomputes
  /// for the next day).
  (Prayer, DateTime)? nextAfter(DateTime now) {
    for (final entry in _markers) {
      if (entry.$2.isAfter(now)) return entry;
    }
    return null;
  }

  // Forbidden-time spans. The calc lib exposes only the final times, not the
  // sun's elevation, so "a spear's length" after sunrise and the yellowing
  // before sunset are documented fixed approximations (they drift a little with
  // latitude/season). The zenith window is anchored on real solar noon.
  static const Duration _afterSunriseSpan = Duration(minutes: 15);
  static const Duration _zenithLead = Duration(minutes: 5); // before zawāl
  static const Duration _beforeSunsetSpan = Duration(minutes: 15);

  /// Solar noon (istiwāʾ) — the midpoint of sunrise and sunset. Maghrib is
  /// sunset, so `(sunrise + maghrib) / 2` is the meridian transit.
  DateTime get solarNoon => sunrise.add(
        Duration(
          microseconds: maghrib.difference(sunrise).inMicroseconds ~/ 2,
        ),
      );

  /// The three daily periods in which prayer is prohibited, in clock order.
  /// Degenerate spans (start ≥ end) are dropped — a guard for unusual inputs;
  /// real data always has solar noon ≤ Dhuhr, so all three hold.
  List<ForbiddenWindow> get forbiddenWindows => [
        ForbiddenWindow(
          reason: ForbiddenReason.afterSunrise,
          start: sunrise,
          end: sunrise.add(_afterSunriseSpan),
        ),
        ForbiddenWindow(
          reason: ForbiddenReason.zenith,
          start: solarNoon.subtract(_zenithLead),
          end: dhuhr, // until the sun declines and Dhuhr enters (zawāl)
        ),
        ForbiddenWindow(
          reason: ForbiddenReason.beforeSunset,
          start: maghrib.subtract(_beforeSunsetSpan),
          end: maghrib,
        ),
      ].where((w) => w.start.isBefore(w.end)).toList();

  /// The forbidden window active at [now], or null when prayer is permitted.
  ForbiddenWindow? forbiddenAt(DateTime now) {
    for (final w in forbiddenWindows) {
      if (w.contains(now)) return w;
    }
    return null;
  }
}
