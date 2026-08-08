import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Decodes the version-2 packed GeoNames city asset built by `build_cities.py`.
///
/// Header: `ALQC | u8 version | u32 rows | u16 timezones | u16 countries`.
/// Three counted UTF-8 pools follow, then 27-byte records and NUL strings.
///
/// The record's trailing `u8 flags` byte is v2's only addition: bit 0 marks a
/// national capital (GeoNames `PPLC`), bit 1 an admin1 capital (`PPLA`). The
/// asset ships inside the app, so v1 is simply rejected rather than supported.
const int _formatVersion = 2;
const int _flagNationalCapital = 1 << 0;
const int _flagAdmin1Capital = 1 << 1;

final class PackedCityIndex {
  const PackedCityIndex._(this.cities);

  final List<PackedCityRecord> cities;

  /// Asset loading is explicit so nothing touches the city data until the
  /// location picker actually needs it.
  static Future<PackedCityIndex> load(AssetBundle bundle) async {
    final data = await bundle.load('assets/geo/cities.bin.gz');
    return decodeGzip(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  static PackedCityIndex decodeGzip(Uint8List compressed) {
    return decode(Uint8List.fromList(gzip.decode(compressed)));
  }

  static PackedCityIndex decode(Uint8List bytes) {
    final reader = _Reader(bytes);
    if (reader.readAscii(4) != 'ALQC') {
      throw const FormatException('Invalid packed city index magic.');
    }
    if (reader.readUint8() != _formatVersion) {
      throw const FormatException('Unsupported packed city index version.');
    }
    final count = reader.readUint32();
    final timezoneCount = reader.readUint16();
    final countryCount = reader.readUint16();
    final zones = reader.readPool();
    final countries = reader.readPool();
    final admins = reader.readPool();
    if (zones.length != timezoneCount || countries.length != countryCount) {
      throw const FormatException('Packed city index pool count mismatch.');
    }
    final pending = List<_Pending>.generate(
      count,
      (_) => _Pending(
        nameOffset: reader.readUint32(),
        asciiOffset: reader.readUint32(),
        country: reader.readUint16(),
        admin: reader.readUint16(),
        latitude: reader.readInt32() / 100000,
        longitude: reader.readInt32() / 100000,
        population: reader.readUint32(),
        timezone: reader.readUint16(),
        flags: reader.readUint8(),
      ),
      growable: false,
    );
    final strings = reader.remaining();
    return PackedCityIndex._(
      List.unmodifiable(
        pending.map(
          (record) => PackedCityRecord(
            name: _string(strings, record.nameOffset),
            asciiName: _string(strings, record.asciiOffset),
            country: _poolAt(countries, record.country, 'country'),
            admin1: _poolAt(admins, record.admin, 'admin1'),
            latitude: record.latitude,
            longitude: record.longitude,
            population: record.population,
            timezoneId: _poolAt(zones, record.timezone, 'timezone'),
            isNationalCapital: record.flags & _flagNationalCapital != 0,
            isAdmin1Capital: record.flags & _flagAdmin1Capital != 0,
          ),
        ),
      ),
    );
  }
}

final class PackedCityRecord {
  const PackedCityRecord({
    required this.name,
    required this.asciiName,
    required this.country,
    required this.admin1,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.timezoneId,
    required this.isNationalCapital,
    required this.isAdmin1Capital,
  });

  final String name;
  final String asciiName;
  final String country;
  final String admin1;
  final double latitude;
  final double longitude;
  final int population;
  final String timezoneId;

  /// GeoNames `PPLC` — the seat of a sovereign state.
  final bool isNationalCapital;

  /// GeoNames `PPLA` — a first-order administrative capital.
  final bool isAdmin1Capital;
}

String _poolAt(List<String> values, int index, String name) {
  if (index >= values.length) {
    throw FormatException('Invalid $name pool index: $index.');
  }
  return values[index];
}

String _string(Uint8List strings, int offset) {
  if (offset >= strings.length) {
    throw FormatException('Invalid string offset: $offset.');
  }
  var end = offset;
  while (end < strings.length && strings[end] != 0) {
    end++;
  }
  if (end == strings.length) {
    throw const FormatException('Unterminated packed city string.');
  }
  return utf8.decode(strings.sublist(offset, end));
}

final class _Pending {
  const _Pending({
    required this.nameOffset,
    required this.asciiOffset,
    required this.country,
    required this.admin,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.timezone,
    required this.flags,
  });

  final int nameOffset;
  final int asciiOffset;
  final int country;
  final int admin;
  final double latitude;
  final double longitude;
  final int population;
  final int timezone;
  final int flags;
}

final class _Reader {
  _Reader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  var _offset = 0;

  int readUint8() => _read(1, () => _data.getUint8(_offset));

  int readUint16() => _read(2, () => _data.getUint16(_offset, Endian.little));

  int readUint32() => _read(4, () => _data.getUint32(_offset, Endian.little));

  int readInt32() => _read(4, () => _data.getInt32(_offset, Endian.little));

  String readAscii(int length) => ascii.decode(_bytesFor(length));

  List<String> readPool() {
    return List<String>.generate(
      readUint16(),
      (_) => utf8.decode(_bytesFor(readUint16())),
      growable: false,
    );
  }

  Uint8List remaining() {
    final result = Uint8List.sublistView(_bytes, _offset);
    _offset = _bytes.length;
    return result;
  }

  int _read(int length, int Function() read) {
    _ensure(length);
    final value = read();
    _offset += length;
    return value;
  }

  Uint8List _bytesFor(int length) {
    _ensure(length);
    final result = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return result;
  }

  void _ensure(int length) {
    if (_offset + length > _bytes.length) {
      throw const FormatException('Truncated packed city index.');
    }
  }
}
