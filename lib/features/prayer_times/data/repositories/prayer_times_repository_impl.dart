import 'package:adhan/adhan.dart' as adhan;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/prayer_times_repository.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  PrayerTimesRepositoryImpl(
    this._prefs,
    this._locationProvider, {
    tz.Location Function(GeoLocation location)? zoneFor,
  }) : _zoneFor = zoneFor ?? _defaultZoneFor;

  final SharedPreferences _prefs;
  final LocationProvider _locationProvider;

  /// Resolves a location to its display zone. Injectable so tests stay
  /// independent of the machine's configured timezone.
  final tz.Location Function(GeoLocation location) _zoneFor;

  static const String _kLat = 'prayer_lat';
  static const String _kLon = 'prayer_lon';
  static const String _kLabel = 'prayer_label';
  static const String _kTimezone = 'prayer_tz';
  static const String _kSource = 'prayer_source';

  // The ONLY two calculation knobs, fixed and never surfaced in the UI:
  //  • method = University of Islamic Sciences, Karachi (18°/18°) — the
  //    de-facto standard across the Indian subcontinent (this app's Urdu/Hindi
  //    audience); matches local references to the minute. MWL's 17° Isha ran
  //    ~6 min early here. (Method sets the Fajr/Isha twilight angles only.)
  //  • Asr    = Standard / Shafi  — the Ahle-Hadith rule (NOT Hanafi). Asr is
  //    method-independent: it's the madhab's shadow ratio, so this is unchanged.
  static const adhan.CalculationMethod _method =
      adhan.CalculationMethod.karachi;
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
      timezoneId: _prefs.getString(_kTimezone),
      source: _sourceFromPrefs(_prefs.getString(_kSource)),
    );
  }

  @override
  Future<LocationResult> acquireLocation() async {
    final result = await _locationProvider.current();
    final loc = result.location;
    if (result.status == LocationStatus.ok && loc != null) {
      await saveLocation(
        GeoLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
          label: loc.label,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> saveLocation(GeoLocation location) async {
    await _prefs.setDouble(_kLat, location.latitude);
    await _prefs.setDouble(_kLon, location.longitude);
    if (location.label == null) {
      await _prefs.remove(_kLabel);
    } else {
      await _prefs.setString(_kLabel, location.label!);
    }
    if (location.timezoneId == null) {
      await _prefs.remove(_kTimezone);
    } else {
      await _prefs.setString(_kTimezone, location.timezoneId!);
    }
    await _prefs.setString(_kSource, location.source.name);
  }

  @override
  Future<void> clearLocation() async {
    await _prefs.remove(_kLat);
    await _prefs.remove(_kLon);
    await _prefs.remove(_kLabel);
    await _prefs.remove(_kTimezone);
    await _prefs.remove(_kSource);
  }

  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) {
    final params = _method.getParameters()
      ..madhab = _madhab
      // Owner decision: at latitudes where the 18° twilight is never reached,
      // divide the night by fajrAngle/60 and ishaAngle/60 (the "angle based"
      // rule) — what Aladhan and most UK/EU timetables use. Previously this was
      // left at adhan's own default (middle of the night), which ran London's
      // Fajr ~18 min early. Never binds at subcontinental latitudes.
      ..highLatitudeRule = adhan.HighLatitudeRule.twilight_angle;
    final adhan.PrayerTimes times;
    try {
      // Zero offset → adhan hands back true UTC instants, and each is converted
      // on its OWN instant below. Passing the *device's* offset (the old code)
      // froze one offset for the whole day, taken from whenever the app
      // happened to be opened — which put every time an hour out on a
      // DST-transition day. Omitting it entirely would make adhan localise
      // internally, which is correct but untestable across machines.
      times = adhan.PrayerTimes(
        adhan.Coordinates(location.latitude, location.longitude),
        adhan.DateComponents.from(date),
        params,
        utcOffset: Duration.zero,
      );
    } catch (_) {
      // Above the polar circles the sun may not rise or set at all, and the
      // library throws on the resulting NaN. No defensible times exist for that
      // day, so report none rather than crashing the app (proper high-latitude
      // support is a future release).
      return null;
    }
    final zone = _zoneFor(location);
    return DailyPrayerTimes(
      fajr: _inZone(times.fajr, zone),
      sunrise: _inZone(times.sunrise, zone),
      dhuhr: _inZone(times.dhuhr, zone),
      asr: _inZone(times.asr, zone),
      maghrib: _inZone(times.maghrib, zone),
      isha: _inZone(times.isha, zone),
      location: location,
      date: date,
    );
  }

  static tz.Location _defaultZoneFor(GeoLocation location) {
    final id = location.timezoneId;
    if (id == null) return tz.local;
    try {
      return tz.getLocation(id);
    } catch (_) {
      return tz.local;
    }
  }

  static LocationSource _sourceFromPrefs(String? value) {
    return LocationSource.values
            .where((source) => source.name == value)
            .firstOrNull ??
        LocationSource.device;
  }

  /// Retains the precise instant while truncating seconds in the selected
  /// location's wall clock. This also applies the offset in force at each time,
  /// including a DST transition day.
  static DateTime _inZone(DateTime utc, tz.Location zone) {
    final t = tz.TZDateTime.from(utc, zone);
    return tz.TZDateTime(zone, t.year, t.month, t.day, t.hour, t.minute);
  }
}
