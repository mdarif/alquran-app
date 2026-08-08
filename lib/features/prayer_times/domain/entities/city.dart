import 'package:equatable/equatable.dart';

import 'geo_location.dart';

/// A searchable offline GeoNames city record.
class City extends Equatable {
  const City({
    required this.name,
    required this.asciiName,
    required this.country,
    required this.admin1,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.timezoneId,
    this.isNationalCapital = false,
  });

  final String name;
  final String asciiName;
  final String country;
  final String admin1;
  final double latitude;
  final double longitude;
  final int population;
  final String timezoneId;

  /// Ranking data only: lets `nearest()` label the capital's metro after the
  /// capital ("New Delhi", not the larger "Delhi" record). Never a calculation
  /// input — see [toGeoLocation].
  final bool isNationalCapital;

  /// Country is presentation/search data only. Karachi/Shafi remains fixed;
  /// only coordinates and the selected city's timezone reach calculations.
  GeoLocation toGeoLocation() => GeoLocation(
        latitude: latitude,
        longitude: longitude,
        label: name,
        timezoneId: timezoneId,
        source: LocationSource.city,
      );

  @override
  List<Object> get props => [
        name,
        asciiName,
        country,
        admin1,
        latitude,
        longitude,
        population,
        timezoneId,
        isNationalCapital,
      ];
}
