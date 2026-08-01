import 'package:adhan/adhan.dart' as adhan;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/prayer_times_repository.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  PrayerTimesRepositoryImpl(
    this._prefs,
    this._locationProvider, {
    DateTime Function(DateTime utc)? toLocal,
  }) : _toLocal = toLocal ?? _deviceLocal;

  final SharedPreferences _prefs;
  final LocationProvider _locationProvider;

  /// UTC instant → the wall clock to display. Injectable so tests are
  /// independent of the machine's timezone; production uses the device's.
  final DateTime Function(DateTime utc) _toLocal;

  static const String _kLat = 'prayer_lat';
  static const String _kLon = 'prayer_lon';
  static const String _kLabel = 'prayer_label';

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
    return DailyPrayerTimes(
      fajr: _toLocal(times.fajr),
      sunrise: _toLocal(times.sunrise),
      dhuhr: _toLocal(times.dhuhr),
      asr: _toLocal(times.asr),
      maghrib: _toLocal(times.maghrib),
      isha: _toLocal(times.isha),
      location: location,
      date: date,
    );
  }

  /// The device's local wall clock for [utc], as a plain (non-UTC) DateTime so
  /// its *instant* matches what it displays — `isAfter(DateTime.now())` then
  /// ranks the day correctly (a UTC-flagged time shifted by an offset once kept
  /// a long-passed Asr as "next" late at night). `toLocal()` applies the offset
  /// in force at that instant, which is what makes DST days come out right.
  static DateTime _deviceLocal(DateTime utc) {
    final t = utc.toLocal();
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }
}
