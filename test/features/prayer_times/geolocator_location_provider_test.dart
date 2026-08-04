import 'package:al_quran/features/prayer_times/data/location/geolocator_location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
