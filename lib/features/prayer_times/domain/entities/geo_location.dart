import 'package:equatable/equatable.dart';

/// A point on Earth for prayer-time calculation. [label] is an optional, purely
/// cosmetic name (we do NOT reverse-geocode — that would need a network, and the
/// app is fully offline); coordinates alone drive the calculation.
class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  @override
  List<Object?> get props => [latitude, longitude, label];
}
