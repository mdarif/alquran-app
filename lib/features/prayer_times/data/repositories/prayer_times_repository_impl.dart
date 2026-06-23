import 'package:adhan/adhan.dart' as adhan;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/prayer_times_repository.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  PrayerTimesRepositoryImpl(this._prefs, this._locationProvider);

  final SharedPreferences _prefs;
  final LocationProvider _locationProvider;

  static const String _kLat = 'prayer_lat';
  static const String _kLon = 'prayer_lon';
  static const String _kLabel = 'prayer_label';

  // The ONLY two calculation knobs, fixed and never surfaced in the UI:
  //  • method = Muslim World League (the widely-adopted global default)
  //  • Asr    = Standard / Shafi  — the Ahle-Hadith rule (NOT Hanafi).
  static const adhan.CalculationMethod _method =
      adhan.CalculationMethod.muslim_world_league;
  static const adhan.Madhab _madhab = adhan.Madhab.shafi;

  @override
  GeoLocation? get location {
    final lat = _prefs.getDouble(_kLat);
    final lon = _prefs.getDouble(_kLon);
    if (lat == null || lon == null) return null;
    return GeoLocation(
      latitude: lat,
      longitude: lon,
      label: _prefs.getString(_kLabel),
    );
  }

  @override
  Future<LocationResult> acquireLocation() async {
    final result = await _locationProvider.current();
    final loc = result.location;
    if (result.status == LocationStatus.ok && loc != null) {
      await _prefs.setDouble(_kLat, loc.latitude);
      await _prefs.setDouble(_kLon, loc.longitude);
      if (loc.label != null) {
        await _prefs.setString(_kLabel, loc.label!);
      }
    }
    return result;
  }

  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) {
    final params = _method.getParameters()..madhab = _madhab;
    // utcOffset from the date itself: in production `date` is the device-local
    // now (user is physically at the location), so this yields local times; in
    // tests a `DateTime.utc(...)` yields deterministic UTC times.
    final times = adhan.PrayerTimes(
      adhan.Coordinates(location.latitude, location.longitude),
      adhan.DateComponents.from(date),
      params,
      utcOffset: date.timeZoneOffset,
    );
    return DailyPrayerTimes(
      fajr: times.fajr,
      sunrise: times.sunrise,
      dhuhr: times.dhuhr,
      asr: times.asr,
      maghrib: times.maghrib,
      isha: times.isha,
      location: location,
      date: date,
    );
  }
}
