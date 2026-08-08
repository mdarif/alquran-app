#!/usr/bin/env python3
"""Build the compact GeoNames city index used by the prayer location picker.

The payload is a versioned binary file: strings are `u16 UTF-8 byte length |
bytes`; each pool begins with a `u16` count. The header repeats timezone and
country counts, while the admin pool carries its own count because the Phase 0
header has no admin-count field. Records are 27-byte little-endian values.

Format v2 appends a `u8 flags` byte per record carrying the GeoNames feature
code the picker needs: bit 0 = national capital (PPLC), bit 1 = admin1 capital
(PPLA). `CityRepositoryImpl` uses bit 0 to prefer "New Delhi" over the larger
"Delhi" record when the user is inside the capital's metro.
"""

from __future__ import annotations

import argparse
import gzip
import io
import struct
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

BASE_URL = 'https://download.geonames.org/export/dump'
FORMAT_VERSION = 2
NATIONAL_CAPITAL = 'PPLC'
ADMIN1_CAPITAL = 'PPLA'
CAPITAL_CODES = {NATIONAL_CAPITAL, ADMIN1_CAPITAL}

FLAG_NATIONAL_CAPITAL = 1 << 0
FLAG_ADMIN1_CAPITAL = 1 << 1


@dataclass(frozen=True)
class City:
    name: str
    ascii_name: str
    country: str
    admin1: str
    latitude: float
    longitude: float
    population: int
    timezone: str
    feature_code: str

    @property
    def flags(self) -> int:
        value = 0
        if self.feature_code == NATIONAL_CAPITAL:
            value |= FLAG_NATIONAL_CAPITAL
        if self.feature_code == ADMIN1_CAPITAL:
            value |= FLAG_ADMIN1_CAPITAL
        return value


def _download(url: str, destination: Path) -> bytes:
    if destination.exists():
        return destination.read_bytes()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url) as response:
        data = response.read()
    destination.write_bytes(data)
    return data


def _country_names(data: bytes) -> dict[str, str]:
    return {
        fields[0]: fields[4]
        for line in data.decode('utf-8').splitlines()
        if line and not line.startswith('#')
        for fields in [line.split('\t')]
    }


def _admin1_names(data: bytes) -> dict[str, str]:
    return {
        fields[0]: fields[1]
        for line in data.decode('utf-8').splitlines()
        if line and not line.startswith('#')
        for fields in [line.split('\t')]
    }


def _cities(archive: bytes, countries: dict[str, str], admins: dict[str, str], floor: int) -> list[City]:
    result: list[City] = []
    with zipfile.ZipFile(io.BytesIO(archive)) as zip_file:
        with zip_file.open('cities15000.txt') as source:
            for raw_line in source:
                fields = raw_line.decode('utf-8').rstrip('\n').split('\t')
                population = int(fields[14])
                if fields[6] != 'P' or (population < floor and fields[7] not in CAPITAL_CODES):
                    continue
                country_code, admin1_code = fields[8], fields[10]
                result.append(City(
                    name=fields[1], ascii_name=fields[2] or fields[1],
                    country=countries.get(country_code, country_code),
                    admin1=admins.get(f'{country_code}.{admin1_code}', admin1_code),
                    latitude=float(fields[4]), longitude=float(fields[5]),
                    population=population, timezone=fields[17],
                    feature_code=fields[7],
                ))
    return result


def _pool(values: list[str]) -> tuple[list[str], dict[str, int]]:
    sorted_values = sorted(set(values))
    return sorted_values, {value: index for index, value in enumerate(sorted_values)}


def _write_pool(output: bytearray, values: list[str]) -> None:
    output.extend(struct.pack('<H', len(values)))
    for value in values:
        encoded = value.encode('utf-8')
        output.extend(struct.pack('<H', len(encoded)))
        output.extend(encoded)


def pack(cities: list[City]) -> bytes:
    timezones, timezone_ids = _pool([city.timezone for city in cities])
    countries, country_ids = _pool([city.country for city in cities])
    admins, admin_ids = _pool([city.admin1 for city in cities])
    if len(cities) > 0xFFFFFFFF or len(timezones) > 0xFFFF or len(countries) > 0xFFFF:
        raise ValueError('City data exceeds packed format limits')
    names, records = bytearray(), bytearray()
    for city in cities:
        name_offset = len(names)
        names.extend(city.name.encode('utf-8'))
        names.append(0)
        ascii_offset = len(names)
        names.extend(city.ascii_name.encode('utf-8'))
        names.append(0)
        records.extend(struct.pack(
            '<IIHHiiIHB', name_offset, ascii_offset, country_ids[city.country],
            admin_ids[city.admin1], round(city.latitude * 100000),
            round(city.longitude * 100000), city.population, timezone_ids[city.timezone],
            city.flags,
        ))
    output = bytearray(b'ALQC')
    output.extend(struct.pack('<BIHH', FORMAT_VERSION, len(cities), len(timezones), len(countries)))
    _write_pool(output, timezones)
    _write_pool(output, countries)
    _write_pool(output, admins)
    output.extend(records)
    output.extend(names)
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--population-floor', type=int, default=15000)
    parser.add_argument('--output', type=Path, default=Path('assets/geo/cities.bin.gz'))
    parser.add_argument('--cache-dir', type=Path, default=Path('/tmp/alquran-geonames'))
    args = parser.parse_args()
    countries = _country_names(_download(f'{BASE_URL}/countryInfo.txt', args.cache_dir / 'countryInfo.txt'))
    # cities15000 supplies an admin1 code, so this GeoNames companion table is
    # needed to fulfil the format's admin1 *names* pool.
    admins = _admin1_names(_download(f'{BASE_URL}/admin1CodesASCII.txt', args.cache_dir / 'admin1CodesASCII.txt'))
    cities = _cities(_download(f'{BASE_URL}/cities15000.zip', args.cache_dir / 'cities15000.zip'), countries, admins, args.population_floor)
    raw = pack(cities)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('wb') as output:
        with gzip.GzipFile(fileobj=output, mode='wb', mtime=0) as compressed:
            compressed.write(raw)
    print(f'population floor: {args.population_floor:,}')
    print(f'rows: {len(cities):,}')
    print(f'uncompressed bytes: {len(raw):,}')
    print(f'gzipped bytes: {args.output.stat().st_size:,}')


if __name__ == '__main__':
    main()
