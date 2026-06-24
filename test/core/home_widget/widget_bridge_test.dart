import 'dart:convert';

import 'package:al_quran/core/home_widget/widget_bridge.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38, label: 'Abu Dhabi');

/// Fixed daily schedule (same shape as the cubit test's fake) so payload
/// assertions are exact and clock-independent.
class _FakeRepo implements PrayerTimesRepository {
  _FakeRepo({this.saved});

  GeoLocation? saved;

  @override
  GeoLocation? get location => saved;

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

  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.ok, _loc);
}

void main() {
  final base = DateTime(2026, 6, 23, 13); // a fixed "now" at 13:00

  test('no location → hasLocation false, no days', () {
    final bridge = WidgetBridge(_FakeRepo(), clock: () => base);
    final p = bridge.buildPayload();

    expect(p.hasLocation, isFalse);
    expect(p.days, isEmpty);
    expect(p.locationLabel, isNull);
    expect(p.generatedAt, base);
  });

  test('with location → today + next 2 days, 6 ordered markers each', () {
    final bridge = WidgetBridge(_FakeRepo(saved: _loc), clock: () => base);
    final p = bridge.buildPayload();

    expect(p.hasLocation, isTrue);
    expect(p.locationLabel, 'Abu Dhabi');
    expect(p.days, hasLength(3));

    // Day 0 is today; dates advance by one civil day.
    expect(p.days[0].date, DateTime(2026, 6, 23));
    expect(p.days[1].date, DateTime(2026, 6, 24));
    expect(p.days[2].date, DateTime(2026, 6, 25));

    final names = p.days.first.markers.map((m) => m.name).toList();
    expect(names, ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);

    // Strictly chronological within the day.
    final m = p.days.first.markers;
    for (var i = 1; i < m.length; i++) {
      expect(
        m[i].at.isAfter(m[i - 1].at),
        isTrue,
        reason: 'marker $i not after ${i - 1}',
      );
    }

    // Sunrise is the only non-salah marker.
    expect(
      m.where((e) => !e.isSalah).map((e) => e.name).toList(),
      ['Sunrise'],
    );
  });

  test('a label-less location yields a null locationLabel', () {
    const noLabel = GeoLocation(latitude: 24.45, longitude: 54.38);
    final bridge = WidgetBridge(_FakeRepo(saved: noLabel), clock: () => base);
    final p = bridge.buildPayload();

    expect(p.hasLocation, isTrue);
    expect(p.locationLabel, isNull);
    expect(p.days, hasLength(3));
  });

  test('encodes to the JSON shape the native widget reads', () {
    final bridge = WidgetBridge(_FakeRepo(saved: _loc), clock: () => base);
    final json =
        jsonDecode(bridge.buildPayload().encode()) as Map<String, dynamic>;

    expect(json['schemaVersion'], 1);
    expect(json['hasLocation'], true);
    expect(json['locationLabel'], 'Abu Dhabi');

    final days = json['days'] as List;
    expect(days, hasLength(3));

    final firstDay = days.first as Map<String, dynamic>;
    expect(firstDay['date'], '2026-06-23'); // civil date, no time/zone

    final fajr = (firstDay['markers'] as List).first as Map<String, dynamic>;
    expect(fajr['name'], 'Fajr');
    expect(fajr['isSalah'], true);
    expect(fajr['at'], '2026-06-23T04:30:00.000'); // device-local wall-clock
  });
}
