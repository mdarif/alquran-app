import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/forbidden_window.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/entities/prayer.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38);

class _FakeRepo implements PrayerTimesRepository {
  _FakeRepo({
    this.saved,
    this.acquireResult = const LocationResult(LocationStatus.ok, _loc),
  });

  GeoLocation? saved;
  LocationResult acquireResult;
  int acquireCalls = 0;

  @override
  GeoLocation? get location => saved;

  @override
  Future<LocationResult> acquireLocation() async {
    acquireCalls++;
    if (acquireResult.status == LocationStatus.ok) {
      saved = acquireResult.location;
    }
    return acquireResult;
  }

  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return DailyPrayerTimes(
      fajr: d.add(const Duration(hours: 4, minutes: 30)),
      sunrise: d.add(const Duration(hours: 6)),
      dhuhr: d.add(const Duration(hours: 12, minutes: 15)),
      asr: d.add(const Duration(hours: 15, minutes: 30)),
      maghrib: d.add(const Duration(hours: 18, minutes: 45)),
      isha: d.add(const Duration(hours: 20, minutes: 15)),
      location: location,
      date: d,
    );
  }
}

void main() {
  final base = DateTime(2026, 6, 23);
  DateTime at(int h, [int m = 0]) => base.add(Duration(hours: h, minutes: m));

  test('unset when there is no saved location', () {
    final cubit = PrayerTimesCubit(_FakeRepo(), clock: () => at(13));
    addTearDown(cubit.close);
    expect(cubit.state.hasLocation, isFalse);
    expect(cubit.state.next, isNull);
  });

  test('computes the next prayer + remaining from the clock', () {
    final cubit = PrayerTimesCubit(_FakeRepo(saved: _loc), clock: () => at(13));
    addTearDown(cubit.close);
    expect(cubit.state.hasLocation, isTrue);
    expect(cubit.state.next!.prayer, Prayer.asr); // 13:00 → 15:30 Asr next
    expect(cubit.state.next!.remaining, const Duration(hours: 2, minutes: 30));
  });

  test('in the dawn window the next marker is Sunrise', () {
    // fajr 4:30, sunrise 6:00 → at 05:00 the next marker is Sunrise.
    final cubit = PrayerTimesCubit(_FakeRepo(saved: _loc), clock: () => at(5));
    addTearDown(cubit.close);
    expect(cubit.state.next!.prayer, Prayer.sunrise);
    expect(cubit.state.next!.at, DateTime(2026, 6, 23, 6));
  });

  test('flags the active forbidden window (after sunrise)', () {
    // sunrise 6:00 → 6:15 is forbidden; 06:05 falls inside it.
    final cubit =
        PrayerTimesCubit(_FakeRepo(saved: _loc), clock: () => at(6, 5));
    addTearDown(cubit.close);
    expect(cubit.state.forbidden?.reason, ForbiddenReason.afterSunrise);
    expect(cubit.state.next!.prayer, Prayer.dhuhr); // sunrise already passed
  });

  test('no forbidden window when prayer is permitted', () {
    final cubit = PrayerTimesCubit(_FakeRepo(saved: _loc), clock: () => at(10));
    addTearDown(cubit.close);
    expect(cubit.state.forbidden, isNull);
  });

  test('after Isha, next rolls over to tomorrow Fajr', () {
    final cubit = PrayerTimesCubit(_FakeRepo(saved: _loc), clock: () => at(23));
    addTearDown(cubit.close);
    expect(cubit.state.next!.prayer, Prayer.fajr);
    expect(cubit.state.next!.at, DateTime(2026, 6, 24, 4, 30));
  });

  test('refresh advances the next prayer as the clock moves', () {
    var hour = 13;
    final cubit = PrayerTimesCubit(
      _FakeRepo(saved: _loc),
      clock: () => at(hour),
    );
    addTearDown(cubit.close);
    expect(cubit.state.next!.prayer, Prayer.asr);
    hour = 16; // past Asr
    cubit.refresh();
    expect(cubit.state.next!.prayer, Prayer.maghrib);
  });

  test('enableLocation OK → persists, computes, nudges the theme', () async {
    var nudged = 0;
    final repo = _FakeRepo(); // no saved location
    final cubit = PrayerTimesCubit(
      repo,
      clock: () => at(13),
      onLocationFixed: () => nudged++,
    );
    addTearDown(cubit.close);
    expect(cubit.state.hasLocation, isFalse);

    await cubit.enableLocation();
    expect(repo.acquireCalls, 1);
    expect(cubit.state.hasLocation, isTrue);
    expect(cubit.state.next!.prayer, Prayer.asr);
    expect(nudged, 1);
  });

  test('enableLocation denied → records status, no theme nudge', () async {
    var nudged = 0;
    final repo = _FakeRepo(
      acquireResult: const LocationResult(LocationStatus.deniedForever),
    );
    final cubit = PrayerTimesCubit(
      repo,
      clock: () => at(13),
      onLocationFixed: () => nudged++,
    );
    addTearDown(cubit.close);

    await cubit.enableLocation();
    expect(cubit.state.hasLocation, isFalse);
    expect(cubit.state.status, LocationStatus.deniedForever);
    expect(nudged, 0);
  });
}
