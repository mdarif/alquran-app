import 'package:al_quran/features/prayer_times/data/location/geolocator_location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/entities/city.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/city_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeCityRepository implements CityRepository {
  @override
  Future<City?> nearest(double latitude, double longitude) async => const City(
        name: 'New Delhi',
        asciiName: 'New Delhi',
        country: 'IN',
        admin1: 'Delhi',
        latitude: 28.61,
        longitude: 77.21,
        population: 317797,
        timezoneId: 'Asia/Kolkata',
      );

  @override
  Future<List<City>> search(String query, {int limit = 20}) async => const [];
}

Position _position() => Position(
      longitude: 77.21,
      latitude: 28.61,
      timestamp: DateTime(2026, 8, 8),
      accuracy: 200,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('opens system location settings when device location is off', () async {
    var opened = false;
    final provider = GeolocatorLocationProvider(
      isLocationServiceEnabled: () async => false,
      openLocationSettings: () async {
        opened = true;
        return true;
      },
    );

    final result = await provider.current();

    expect(result.status, LocationStatus.serviceOff);
    expect(opened, isTrue);
  });

  test('labels device coordinates with the nearest offline city', () async {
    final provider = GeolocatorLocationProvider(
      cityRepository: _FakeCityRepository(),
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      getLastKnownPosition: () async => _position(),
    );

    final result = await provider.current();

    expect(result.status, LocationStatus.ok);
    expect(result.location?.label, 'New Delhi');
    expect(result.location?.timezoneId, 'Asia/Kolkata');
  });
}
