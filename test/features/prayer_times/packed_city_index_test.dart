import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:al_quran/features/prayer_times/data/cities/packed_city_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the version-2 packed city format byte-for-byte', () {
    final raw = Uint8List.fromList(<int>[
      ...'ALQC'.codeUnits,
      2,
      2,
      0,
      0,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
      12,
      0,
      ...'Asia/Karachi'.codeUnits,
      1,
      0,
      8,
      0,
      ...'Pakistan'.codeUnits,
      1,
      0,
      5,
      0,
      ...'Sindh'.codeUnits,
      ..._record(0, 10, 2486000, 6710000, 14910352, flags: 2),
      ..._record(18, 25, -3387000, 15121000, 5312163, flags: 1),
      ...utf8.encode('Kārāchi\x00Karachi\x00Sydney\x00Sydney\x00'),
    ]);
    final cities = PackedCityIndex.decodeGzip(
      Uint8List.fromList(gzip.encode(raw)),
    ).cities;
    expect(cities, hasLength(2));
    expect(cities.first.name, 'Kārāchi');
    expect(cities.first.asciiName, 'Karachi');
    expect(cities.first.country, 'Pakistan');
    expect(cities.first.admin1, 'Sindh');
    expect(cities.first.latitude, 24.86);
    expect(cities.first.longitude, 67.1);
    expect(cities.first.population, 14910352);
    expect(cities.first.timezoneId, 'Asia/Karachi');
    expect(cities.first.isNationalCapital, isFalse);
    expect(cities.first.isAdmin1Capital, isTrue);
    expect(cities.last.name, 'Sydney');
    expect(cities.last.latitude, -33.87);
    expect(cities.last.longitude, 151.21);
    expect(cities.last.isNationalCapital, isTrue);
  });

  test('rejects the retired version-1 layout rather than misreading it', () {
    final raw = Uint8List.fromList(<int>[...'ALQC'.codeUnits, 1, 0, 0, 0, 0]);

    expect(
      () => PackedCityIndex.decodeGzip(Uint8List.fromList(gzip.encode(raw))),
      throwsA(isA<FormatException>()),
    );
  });
}

List<int> _record(
  int name,
  int ascii,
  int lat,
  int lon,
  int population, {
  int flags = 0,
}) {
  final data = ByteData(27)
    ..setUint32(0, name, Endian.little)
    ..setUint32(4, ascii, Endian.little)
    ..setUint16(8, 0, Endian.little)
    ..setUint16(10, 0, Endian.little)
    ..setInt32(12, lat, Endian.little)
    ..setInt32(16, lon, Endian.little)
    ..setUint32(20, population, Endian.little)
    ..setUint16(24, 0, Endian.little)
    ..setUint8(26, flags);
  return data.buffer.asUint8List();
}
