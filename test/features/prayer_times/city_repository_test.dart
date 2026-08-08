import 'package:al_quran/features/prayer_times/data/repositories/city_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CityRepositoryImpl repository;

  setUp(() {
    repository = CityRepositoryImpl();
  });

  test('search ranks Karachi first for its prefix', () async {
    final results = await repository.search('kar');
    expect(results, isNotEmpty);
    expect(results.first.asciiName, 'Karachi');
  });

  test('search folds accented queries to GeoNames ASCII city names', () async {
    final results = await repository.search('são');
    expect(results, isNotEmpty);
    expect(results.first.asciiName, 'Sao Paulo');
  });

  test('nearest resolves known Karachi coordinates to Karachi', () async {
    final city = await repository.nearest(24.8607, 67.0011);
    expect(city?.asciiName, 'Karachi');
    expect(city?.timezoneId, 'Asia/Karachi');
  });

  test('nearest prefers a nearby display city over a tiny locality', () async {
    final city = await repository.nearest(28.5161, 77.30993);
    expect(city?.asciiName, 'New Delhi');
    expect(city?.timezoneId, 'Asia/Kolkata');
  });

  // Ranking by distance used to hand these back as Najafgarh, Rohini, Karol
  // Bagh and — from Noida, via an admin1 inherited from the closest Haryana
  // village — Faridabad, a city in another state.
  group('nearest labels a metro after the metro, not the closest ward', () {
    const points = <String, (double, double)>{
      'Connaught Place': (28.6139, 77.2090),
      'Dwarka': (28.5921, 77.0460),
      'Rohini': (28.7495, 77.0565),
      'Mayur Vihar': (28.6100, 77.3000),
      'Shahdara': (28.6700, 77.2900),
      'Janakpuri': (28.6219, 77.0878),
      'Noida': (28.5355, 77.3910),
    };

    points.forEach((place, coordinates) {
      test('$place resolves to New Delhi', () async {
        final city = await repository.nearest(coordinates.$1, coordinates.$2);
        expect(city?.name, 'New Delhi');
        expect(city?.timezoneId, 'Asia/Kolkata');
      });
    });
  });

  group('nearest leaves a substantial neighbour its own name', () {
    const points = <String, (double, double)>{
      'Gurugram': (28.4595, 77.0266),
      'Faridabad': (28.4089, 77.3178),
      // Islamabad is only 14 km away, so a plain capital radius would have
      // relabelled everyone in Rawalpindi.
      'Rawalpindi': (33.5651, 73.0169),
      'Islamabad': (33.6844, 73.0479),
      'Mumbai': (19.0596, 72.8295),
      'London': (51.5136, -0.1365),
      'Dubai': (25.0805, 55.1403),
    };

    points.forEach((expected, coordinates) {
      test(expected, () async {
        final city = await repository.nearest(coordinates.$1, coordinates.$2);
        expect(city?.name, expected);
      });
    });
  });

  test('nearest flags the capital it picked', () async {
    final city = await repository.nearest(28.6139, 77.2090);
    expect(city?.isNationalCapital, isTrue);
  });

  test('full-asset search completes within the 500 ms budget', () async {
    final stopwatch = Stopwatch()..start();
    await repository.search('kar');
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });
}
