import '../entities/daily_prayer_times.dart';
import '../entities/geo_location.dart';
import '../location/location_provider.dart';

/// Reads/persists the user's location and computes prayer times on-device
/// (offline). The calculation method (University of Islamic Sciences, Karachi)
/// and the Asr rule (Standard/Shafi — Ahle-Hadith) are fixed in the
/// implementation and never surfaced.
abstract interface class PrayerTimesRepository {
  /// The saved location, or null until a fix has been obtained. Synchronous
  /// (reads the cached value) — mirrors the settings-repo pattern.
  GeoLocation? get location;

  /// Acquire (via GPS) and persist the device location. Returns the outcome;
  /// the caller reacts to [LocationStatus]. Never throws.
  Future<LocationResult> acquireLocation();

  /// Prayer times for [location] on [date] (local DateTimes).
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date);
}
