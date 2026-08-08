import 'package:equatable/equatable.dart';

enum LocationSource { device, city, coordinates }

/// A point on Earth for prayer-time calculation. [label] is an optional, purely
/// cosmetic name (we do NOT reverse-geocode — that would need a network, and the
/// app is fully offline); coordinates alone drive the calculation.
class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.timezoneId,
    this.source = LocationSource.device,
  });

  final double latitude;
  final double longitude;
  final String? label;
  final String? timezoneId;
  final LocationSource source;

  @override
  List<Object?> get props => [latitude, longitude, label, timezoneId, source];
}
