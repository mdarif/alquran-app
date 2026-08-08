import 'package:adhan/adhan.dart' as adhan;
import 'package:al_quran/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
  tz.Location? zone,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  if (zone == null) {
    return PrayerTimesRepositoryImpl(sharedPreferences, provider);
  }
  return PrayerTimesRepositoryImpl(
    sharedPreferences,
    provider,
    zoneFor: (_) => zone,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final provider = _FakeLocationProvider(
    const LocationResult(LocationStatus.ok, _abuDhabi),
  );

  group('PrayerTimesRepositoryImpl.timesFor (adhan)', () {
    test('produces the six daily times in ascending order, on the date',
        () async {
      final repo = await _repo(provider);
      final t = repo.timesFor(_abuDhabi, _date)!;
      final ordered = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].isAfter(ordered[i - 1]),
          isTrue,
          reason: 'time $i not after ${i - 1}',
        );
      }
      // Plausible for Abu Dhabi in June (UTC times; local = +4): Fajr early AM.
      expect(t.fajr.day, 23);
      expect(t.dhuhr.hour, inInclusiveRange(7, 9)); // ~08:0x UTC = ~12:0x local
    });

    test('Asr uses the Standard/Shafi rule (NOT Hanafi) — creed guard',
        () async {
      final repo = await _repo(provider);
      final ours = repo.timesFor(_abuDhabi, _date)!.asr;

      // Compute the Hanafi Asr directly; it is strictly LATER than Shafi's.
      // (Asr is method-independent — only the madhab differs here.)
      final hanafi = adhan.PrayerTimes(
        adhan.Coordinates(_abuDhabi.latitude, _abuDhabi.longitude),
        adhan.DateComponents.from(_date),
        adhan.CalculationMethod.karachi.getParameters()
          ..madhab = adhan.Madhab.hanafi,
        utcOffset: _date.timeZoneOffset,
      ).asr;

      // Compare time-of-day (both on the same UTC clock for this UTC date), not
      // the instant — `ours` is now a normalized local DateTime (see below).
      int tod(DateTime t) => t.hour * 60 + t.minute;
      expect(
        tod(ours) < tod(hanafi),
        isTrue,
        reason: 'Asr must be Shafi (earlier), got ours=$ours hanafi=$hanafi',
      );
    });

    test('returns zoned times so isAfter(now) ranks instants correctly',
        () async {
      // A TZDateTime can be UTC, but still represents the exact instant and
      // supports DateTime's normal comparison APIs.
      final repo = await _repo(provider);
      final t = repo.timesFor(_abuDhabi, _date)!;

      expect(t.asr, isA<tz.TZDateTime>());
      expect(t.isha, isA<tz.TZDateTime>());

      // One minute past Isha, every prayer has passed → nextAfter is null and
      // the cubit rolls over to tomorrow's Fajr (instead of resurfacing Asr).
      final afterIsha = t.isha.add(const Duration(minutes: 1));
      expect(t.asr.isAfter(afterIsha), isFalse);
      expect(t.nextAfter(afterIsha), isNull);
    });

    test('the selected city controls wall-clock rendering, not the device',
        () async {
      final london = await _repo(provider);
      final karachi = await _repo(provider);
      final londonTimes = london.timesFor(
        const GeoLocation(
          latitude: 24.4539,
          longitude: 54.3773,
          timezoneId: 'Europe/London',
        ),
        _date,
      )!;
      final karachiTimes = karachi.timesFor(
        const GeoLocation(
          latitude: 24.4539,
          longitude: 54.3773,
          timezoneId: 'Asia/Karachi',
        ),
        _date,
      )!;

      expect(londonTimes.fajr.difference(karachiTimes.fajr), Duration.zero);
      expect(londonTimes.fajr.hour, isNot(karachiTimes.fajr.hour));
    });
  });

  group('PrayerTimesRepositoryImpl — daylight saving', () {
    const london = GeoLocation(latitude: 51.5074, longitude: -0.1278);

    test('converts each time on its own instant, not one whole-day offset',
        () async {
      final repo = await _repo(provider, zone: tz.getLocation('Europe/London'));
      final t = repo.timesFor(london, DateTime(2026, 10, 25))!;

      // GMT wall clock — what the clock on the wall reads at those moments.
      expect('${t.fajr.hour}:${t.fajr.minute}', '4:49');
      expect('${t.sunrise.hour}:${t.sunrise.minute}', '6:42');
      expect('${t.dhuhr.hour}:${t.dhuhr.minute}', '11:46');
      expect('${t.maghrib.hour}:${t.maghrib.minute}', '16:47');
    });

    test('the result does not depend on the time of day it was computed at',
        () async {
      final repo = await _repo(provider, zone: tz.getLocation('Europe/London'));
      // Pre-switch (00:30 BST) vs post-switch (12:00 GMT) on the same date.
      final early = repo.timesFor(london, DateTime(2026, 10, 25, 0, 30))!;
      final later = repo.timesFor(london, DateTime(2026, 10, 25, 12))!;
      expect(early.fajr, later.fajr);
      expect(early.maghrib, later.maghrib);
    });
  });

  group('PrayerTimesRepositoryImpl — high latitudes', () {
    test('Fajr/Isha use the angle-based rule (owner decision)', () async {
      // London, 1 Aug 2026: the 18° twilight is never reached, so the rule
      // decides. Angle-based gives 02:49 / 23:23 BST — Aladhan on the Karachi
      // method says 02:50 / 23:23, i.e. the same rule to within the libraries'
      // ±1 min rounding. The old library default (middle of the night) gave
      // 02:32 / 23:38, ~18 min early. Times here are on the UTC clock = BST−1h.
      final repo = await _repo(provider);
      final t = repo.timesFor(
        const GeoLocation(latitude: 51.5074, longitude: -0.1278),
        DateTime.utc(2026, 8, 1),
      )!;
      int mins(DateTime x) => x.hour * 60 + x.minute;
      // Reference (Aladhan, Karachi method, angle-based), on the UTC clock.
      // A 2-minute tolerance absorbs the libraries' rounding conventions
      // without letting a whole rule change slip through.
      expect((mins(t.fajr) - (1 * 60 + 50)).abs(), lessThanOrEqualTo(2));
      expect((mins(t.isha) - (22 * 60 + 23)).abs(), lessThanOrEqualTo(2));
      // Explicitly NOT the old library default (middle of the night), which
      // put Fajr at 01:32 and Isha at 22:38 UTC.
      expect(mins(t.fajr), greaterThan(1 * 60 + 40));
      expect(mins(t.isha), lessThan(22 * 60 + 30));
    });

    test('returns null (never throws) where the sun does not rise or set',
        () async {
      final repo = await _repo(provider);
      // Svalbard: polar night in December, midnight sun in June. The adhan
      // package throws "value should not be infinite or NaN" for both — which
      // used to propagate out of the theme resolver and the cubit constructor.
      const svalbard = GeoLocation(latitude: 78.22, longitude: 15.65);
      expect(repo.timesFor(svalbard, DateTime.utc(2026, 12, 21)), isNull);
      expect(repo.timesFor(svalbard, DateTime.utc(2026, 6, 21)), isNull);
      // …and a normal latitude on the same day still computes.
      expect(repo.timesFor(_abuDhabi, DateTime.utc(2026, 12, 21)), isNotNull);
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
      expect(repo.location?.source, LocationSource.device);
      expect(repo.location?.timezoneId, isNull);
    });

    test('saveLocation persists city timezone/source and clears stale labels',
        () async {
      final repo = await _repo(provider, prefs: {'prayer_label': 'Stale'});
      await repo.saveLocation(
        const GeoLocation(
          latitude: 24.86,
          longitude: 67.01,
          timezoneId: 'Asia/Karachi',
          source: LocationSource.city,
        ),
      );
      expect(repo.location?.label, isNull);
      expect(repo.location?.timezoneId, 'Asia/Karachi');
      expect(repo.location?.source, LocationSource.city);
    });

    test('clearLocation removes every persisted field', () async {
      final repo = await _repo(
        provider,
        prefs: {
          'prayer_lat': 25.2,
          'prayer_lon': 55.27,
          'prayer_label': 'Dubai',
          'prayer_tz': 'Asia/Dubai',
          'prayer_source': 'city',
        },
      );
      await repo.clearLocation();
      expect(repo.location, isNull);
    });
  });
}
