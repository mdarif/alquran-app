import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_location.dart';
import '../../domain/location/location_provider.dart';

/// Device location via `geolocator`. Low accuracy is deliberate — prayer times
/// are insensitive to a few km, and a coarse fix is faster and less invasive.
class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider();

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }
      // A cached fix is plenty for prayer times and instant; fall back to a
      // fresh coarse fix if there's none.
      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          );
      return LocationResult(
        LocationStatus.ok,
        GeoLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }
}
