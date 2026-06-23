import 'package:adhan/adhan.dart' as adhan;
import 'package:al_quran/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A scriptable LocationProvider so the repo can be tested without `geolocator`.
class _FakeLocationProvider implements LocationProvider {
  _FakeLocationProvider(this.result);
  LocationResult result;
  int calls = 0;
  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}

// Abu Dhabi, on a fixed UTC day so the computed times are deterministic across
// machines (utcOffset comes from the date: DateTime.utc → 0 → UTC times).
const _abuDhabi = GeoLocation(latitude: 24.4539, longitude: 54.3773);
final _date = DateTime.utc(2026, 6, 23);

Future<PrayerTimesRepositoryImpl> _repo(
  _FakeLocationProvider provider, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  return PrayerTimesRepositoryImpl(
    await SharedPreferences.getInstance(),
    provider,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final provider = _FakeLocationProvider(const LocationResult(
    LocationStatus.ok,
    _abuDhabi,
  ));

  group('PrayerTimesRepositoryImpl.timesFor (adhan)', () {
    test('produces the six daily times in ascending order, on the date',
        () async {
      final repo = await _repo(provider);
      final t = repo.timesFor(_abuDhabi, _date);
      final ordered = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].isAfter(ordered[i - 1]), isTrue,
            reason: 'time $i not after ${i - 1}');
      }
      // Plausible for Abu Dhabi in June (UTC times; local = +4): Fajr early AM.
      expect(t.fajr.day, 23);
      expect(t.dhuhr.hour, inInclusiveRange(7, 9)); // ~08:0x UTC = ~12:0x local
    });

    test('Asr uses the Standard/Shafi rule (NOT Hanafi) — creed guard',
        () async {
      final repo = await _repo(provider);
      final ours = repo.timesFor(_abuDhabi, _date).asr;

      // Compute the Hanafi Asr directly; it is strictly LATER than Shafi's.
      final hanafi = adhan.PrayerTimes(
        adhan.Coordinates(_abuDhabi.latitude, _abuDhabi.longitude),
        adhan.DateComponents.from(_date),
        adhan.CalculationMethod.muslim_world_league.getParameters()
          ..madhab = adhan.Madhab.hanafi,
        utcOffset: _date.timeZoneOffset,
      ).asr;

      expect(ours.isBefore(hanafi), isTrue,
          reason: 'Asr must be Shafi (earlier), got ours=$ours hanafi=$hanafi');
    });
  });

  group('PrayerTimesRepositoryImpl — location persistence', () {
    test('location is null until a fix is acquired', () async {
      final repo = await _repo(provider);
      expect(repo.location, isNull);
    });

    test('acquireLocation persists an OK fix; the getter then returns it',
        () async {
      final repo = await _repo(provider);
      final result = await repo.acquireLocation();
      expect(result.status, LocationStatus.ok);
      expect(repo.location?.latitude, _abuDhabi.latitude);
      expect(repo.location?.longitude, _abuDhabi.longitude);
    });

    test('a denied fix is NOT persisted', () async {
      final denied = _FakeLocationProvider(
        const LocationResult(LocationStatus.denied),
      );
      final repo = await _repo(denied);
      final result = await repo.acquireLocation();
      expect(result.status, LocationStatus.denied);
      expect(repo.location, isNull);
    });

    test('reads a previously persisted location on construction', () async {
      final repo = await _repo(
        provider,
        prefs: {'prayer_lat': 25.2, 'prayer_lon': 55.27},
      );
      expect(repo.location?.latitude, 25.2);
    });
  });
}
