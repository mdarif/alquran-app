import '../entities/city.dart';

/// Offline search and coordinate-to-nearest-city lookup for manual locations.
abstract interface class CityRepository {
  Future<List<City>> search(String query, {int limit = 20});

  Future<City?> nearest(double latitude, double longitude);
}
