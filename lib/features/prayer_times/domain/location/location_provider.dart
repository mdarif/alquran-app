import '../entities/geo_location.dart';

/// Outcome of a location request — drives both the indicator's affordance and
/// whether prayer times can be shown at all.
enum LocationStatus {
  ok,
  denied, // can ask again
  deniedForever, // must go to system settings
  serviceOff, // device location services disabled
  unavailable, // no fix obtained / unexpected failure
}

class LocationResult {
  const LocationResult(this.status, [this.location]);

  final LocationStatus status;
  final GeoLocation? location;
}

/// Abstracts device location so the repository/cubit never import `geolocator`
/// (keeps the data layer swappable and the cubit testable with a fake).
abstract interface class LocationProvider {
  /// Resolve the device's current position, requesting permission if needed.
  /// Never throws — failures map to a [LocationStatus].
  Future<LocationResult> current();
}
