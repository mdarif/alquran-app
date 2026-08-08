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

  /// Persist a manually chosen location. City timezones travel with the saved
  /// coordinates; device GPS locations deliberately use a null timezone id.
  Future<void> saveLocation(GeoLocation location);

  /// Remove the saved location and all of its associated display metadata.
  Future<void> clearLocation();

  /// Prayer times for [location] on [date] (local DateTimes), or **null** when
  /// no defensible schedule exists for that day — above the polar circles the
  /// sun may not rise or set at all. Callers must degrade gracefully (hide the
  /// prayer UI) rather than assume a value. Never throws.
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date);
}
