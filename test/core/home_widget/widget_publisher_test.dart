import 'dart:convert';

import 'package:al_quran/core/home_widget/widget_bridge.dart';
import 'package:al_quran/core/home_widget/widget_publisher.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38, label: 'Abu Dhabi');

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

/// Records what the publisher hands to the platform seam.
class _RecordingClient implements HomeWidgetClient {
  String? appGroupId;
  final Map<String, String> saved = {};
  final List<String> androidUpdated = [];
  final List<String> iosUpdated = [];

  @override
  Future<void> setAppGroupId(String groupId) async => appGroupId = groupId;

  @override
  Future<void> saveData(String key, String value) async => saved[key] = value;

  @override
  Future<void> update({String? qualifiedAndroidName, String? iOSName}) async {
    if (qualifiedAndroidName != null) androidUpdated.add(qualifiedAndroidName);
    if (iOSName != null) iosUpdated.add(iOSName);
  }
}

/// Fails mid-publish — proves publish() never rethrows.
class _ThrowingClient implements HomeWidgetClient {
  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> saveData(String key, String value) async =>
      throw Exception('plugin unavailable');

  @override
  Future<void> update({String? qualifiedAndroidName, String? iOSName}) async {}
}

void main() {
  final base = DateTime(2026, 6, 23, 13);

  WidgetPublisher publisher(PrayerTimesRepository repo, HomeWidgetClient client) =>
      WidgetPublisher(WidgetBridge(repo, clock: () => base), client);

  test('publishes the payload + redraws both Android providers and iOS kinds',
      () async {
    final client = _RecordingClient();
    await publisher(_FakeRepo(saved: _loc), client).publish();

    // App Group set so the iOS extension can read the shared container.
    expect(client.appGroupId, WidgetPublisher.appGroupId);

    // Saved under the agreed key, and it's the bridge's JSON.
    final raw = client.saved[WidgetPublisher.payloadKey];
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['hasLocation'], true);
    expect((json['days'] as List), hasLength(3));

    // Every widget on both platforms is asked to redraw.
    expect(client.androidUpdated, WidgetPublisher.androidProviders);
    expect(client.iosUpdated, WidgetPublisher.iosWidgetKinds);
  });

  test('still publishes a (location-less) payload when no location is set',
      () async {
    final client = _RecordingClient();
    await publisher(_FakeRepo(), client).publish();

    final raw = client.saved[WidgetPublisher.payloadKey];
    expect(raw, isNotNull);
    expect((jsonDecode(raw!) as Map<String, dynamic>)['hasLocation'], false);
    expect(client.androidUpdated, WidgetPublisher.androidProviders);
    expect(client.iosUpdated, WidgetPublisher.iosWidgetKinds);
  });

  test('swallows plugin errors — a failing widget push never breaks the app',
      () async {
    // Must not throw.
    await publisher(_FakeRepo(saved: _loc), _ThrowingClient()).publish();
  });
}
