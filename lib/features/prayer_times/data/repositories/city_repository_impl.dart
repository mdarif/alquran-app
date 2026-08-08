import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';
import '../cities/packed_city_index.dart';

typedef CityIndexLoader = Future<PackedCityIndex> Function();

/// In-memory index over the compact GeoNames asset. Construction is cheap and
/// loading is deferred until a search/nearest call; [dispose] frees its cache.
class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl({CityIndexLoader? loadIndex})
      : _loadIndex = loadIndex ?? (() => PackedCityIndex.load(rootBundle));

  final CityIndexLoader _loadIndex;
  Future<List<City>>? _cities;

  Future<List<City>> _all() {
    return _cities ??= _loadIndex().then(
      (index) => List.unmodifiable(
        index.cities
            .map(
              (record) => City(
                name: record.name,
                asciiName: record.asciiName,
                country: record.country,
                admin1: record.admin1,
                latitude: record.latitude,
                longitude: record.longitude,
                population: record.population,
                timezoneId: record.timezoneId,
                isNationalCapital: record.isNationalCapital,
              ),
            )
            .toList(),
      ),
    );
  }

  /// Releases the decoded city records when the location-picker lifecycle ends.
  void dispose() => _cities = null;

  @override
  Future<List<City>> search(String query, {int limit = 20}) async {
    if (limit <= 0) return const [];
    final normalized = _fold(query);
    if (normalized.isEmpty) return const [];
    final matches = <(City, int)>[];
    for (final city in await _all()) {
      final score = math.max(
        _score(_fold(city.name), normalized),
        _score(_fold(city.asciiName), normalized),
      );
      if (score > 0) matches.add((city, score));
    }
    matches.sort((a, b) {
      final score = b.$2.compareTo(a.$2);
      return score != 0 ? score : b.$1.population.compareTo(a.$1.population);
    });
    return List.unmodifiable(matches.take(limit).map((match) => match.$1));
  }

  /// The name a person standing at these coordinates would give their location.
  ///
  /// Not the closest record: inside a metro that is almost always a ward or
  /// village (Hashtsāl, Deoli, Jaitpur), and ranking the shortlist by distance
  /// let a 500k suburb beat an 11M metro 1 km further out. Two rules instead:
  ///
  /// 1. **Dominance** — maximise `population / (distance + k)`, so a big city
  ///    reaches further than a small one but never swallows a substantial
  ///    neighbour. `k` is small (2 km) so Gurugram keeps its own name against
  ///    Delhi 30 km away, while every Delhi ward resolves to the metro.
  /// 2. **Capital** — a national capital within [_capitalRadiusKm] wins if it
  ///    is not meaningfully further than the dominant city ([_capitalSlackKm]).
  ///    That yields "New Delhi" across the NCT, where GeoNames also carries a
  ///    much larger "Delhi" record — but leaves Rawalpindi alone, since
  ///    Islamabad sits 14 km away while Rawalpindi itself is underfoot.
  ///
  /// Deliberately unfiltered by country/admin1: deriving that filter from the
  /// closest record labelled Noida as "Faridabad", a city in another state,
  /// because the closest record happened to be a Haryana village.
  @override
  Future<City?> nearest(double latitude, double longitude) async {
    final cities = await _all();
    City? dominant;
    var dominantDistance = double.infinity;
    var dominantScore = double.negativeInfinity;
    City? fallback;
    var fallbackDistance = double.infinity;

    for (final city in cities) {
      final distance =
          _haversine(latitude, longitude, city.latitude, city.longitude);
      if (distance < fallbackDistance) {
        fallbackDistance = distance;
        fallback = city;
      }
      final score = city.population / (distance + _dominanceSofteningKm);
      if (score > dominantScore) {
        dominantScore = score;
        dominantDistance = distance;
        dominant = city;
      }
    }
    if (dominant == null) return fallback;

    City? capital;
    var capitalDistance = double.infinity;
    for (final city in cities) {
      if (!city.isNationalCapital) continue;
      final distance =
          _haversine(latitude, longitude, city.latitude, city.longitude);
      if (distance <= _capitalRadiusKm &&
          distance <= dominantDistance + _capitalSlackKm &&
          distance < capitalDistance) {
        capitalDistance = distance;
        capital = city;
      }
    }
    return capital ?? dominant;
  }
}

/// Added to the distance in the dominance score so a city you are standing in
/// scores finitely rather than dividing by zero. Tuned against the real asset:
/// large enough that Delhi's wards resolve to the metro, small enough that
/// substantial neighbours — Gurugram, Faridabad, Rawalpindi — keep their own
/// name. Genuine suburbs (Thane, Croydon) do resolve to the metro, which is
/// what a person there would say anyway.
const double _dominanceSofteningKm = 2;
const double _capitalRadiusKm = 25;
const double _capitalSlackKm = 10;

int _score(String name, String query) {
  if (name == query) return 4;
  if (name.startsWith(query)) return 3;
  if (name.split(' ').any((word) => word.startsWith(query))) return 2;
  return name.contains(query) ? 1 : 0;
}

String _fold(String value) {
  const accented = 'àáâãäåāăąçćčďèéêëēėęěĝğìíîïīįłñńňòóôõöøōŕřśšşťùúûüūůýÿžźż';
  const plain = 'aaaaaaaaacccdeeeeeeeeggiiiiiilnnnoooooooorrssstuuuuuuyyzzz';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    final index = accented.indexOf(character);
    if (index >= 0) {
      buffer.write(plain[index]);
    } else if ((rune >= 0x61 && rune <= 0x7a) ||
        (rune >= 0x30 && rune <= 0x39)) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

double _haversine(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const radians = 0.017453292519943295;
  const earthRadiusKm = 6371.0;
  final latitudeDelta = (latitude2 - latitude1) * radians;
  final longitudeDelta = (longitude2 - longitude1) * radians;
  final latitudeSine = math.sin(latitudeDelta / 2);
  final longitudeSine = math.sin(longitudeDelta / 2);
  final a = latitudeSine * latitudeSine +
      longitudeSine *
          longitudeSine *
          math.cos(latitude1 * radians) *
          math.cos(latitude2 * radians);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
