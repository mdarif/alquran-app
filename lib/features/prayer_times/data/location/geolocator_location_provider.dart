import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_location.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/city_repository.dart';

/// Device location via `geolocator`. Low accuracy is deliberate — prayer times
/// are insensitive to a few km, and a coarse fix is faster and less invasive.
class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider({
    CityRepository? cityRepository,
    Future<bool> Function()? isLocationServiceEnabled,
    Future<bool> Function()? openLocationSettings,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position?> Function()? getLastKnownPosition,
    Future<Position> Function({LocationSettings? locationSettings})?
        getCurrentPosition,
  })  : _cityRepository = cityRepository,
        _isLocationServiceEnabled =
            isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
        _openLocationSettings =
            openLocationSettings ?? Geolocator.openLocationSettings,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _getLastKnownPosition =
            getLastKnownPosition ?? Geolocator.getLastKnownPosition,
        _getCurrentPosition =
            getCurrentPosition ?? Geolocator.getCurrentPosition;

  final CityRepository? _cityRepository;
  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<bool> Function() _openLocationSettings;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position?> Function() _getLastKnownPosition;
  final Future<Position> Function({LocationSettings? locationSettings})
      _getCurrentPosition;

  @override
  Future<LocationResult> current() async {
    try {
      if (!await _isLocationServiceEnabled()) {
        await _openLocationSettings();
        return const LocationResult(LocationStatus.serviceOff);
      }
      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }
      // A cached fix is plenty for prayer times and instant; fall back to a
      // fresh coarse fix if there's none. The timeLimit guarantees we never hang
      // forever waiting for a fix that won't come (services on but no signal /
      // an emulator with no location): it throws, caught below → `unavailable`,
      // so the indicator degrades to the enable affordance instead of limbo.
      final position = await _getLastKnownPosition() ??
          await _getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
      final nearest = await _cityRepository?.nearest(
        position.latitude,
        position.longitude,
      );
      return LocationResult(
        LocationStatus.ok,
        GeoLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          label: nearest?.name,
          timezoneId: nearest?.timezoneId,
        ),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }
}
