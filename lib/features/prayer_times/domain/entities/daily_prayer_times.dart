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

  /// The next obligatory prayer strictly after [now], or null once all of this
  /// day's prayers have passed (the caller then recomputes for the next day).
  (Prayer, DateTime)? nextAfter(DateTime now) {
    for (final entry in schedule) {
      if (entry.$2.isAfter(now)) return entry;
    }
    return null;
  }
}
