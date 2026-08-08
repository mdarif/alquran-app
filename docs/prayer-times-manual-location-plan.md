> # ⛔ SUPERSEDED — DO NOT IMPLEMENT FROM THIS FILE
>
> Superseded 2026-08-08 by **`docs/prayer-times-plan.md`**, which is the only
> current spec. This document is retained for history only.
>
> Its central technical choices were **rejected**:
> - `lat_lng_to_timezone` (+2.3 MB) — not needed; GeoNames ships an IANA
>   timezone per city, and the `timezone` package is already a dependency.
> - A bundled city SQLite/Drift database — replaced by a gzipped packed asset
>   decoded lazily in Dart (no seeder, no codegen, no version marker).
> - The +3.5 MB bundle delta — the current plan targets ~+0.6 MB.
>
> If you are an agent implementing this feature: stop reading here and open
> `docs/prayer-times-plan.md` instead.

---

# Prayer Times: Manual Location Selection & Timezone Inference Plan

**Date:** 2026-08-08  
**Status:** ⛔ SUPERSEDED by `docs/prayer-times-plan.md` — historical reference only  
**Owner Decision Pending:** City data source + Phase 2 enhancements

---

## Executive Summary

Add manual city selection to prayer times via a lightweight offline approach:
- Users can search for a city or manually enter coordinates
- Timezone is **automatically inferred** from coordinates using `lat_lng_to_timezone` package (fully offline)
- No timezone data needs to be bundled; it's computed on-demand
- Bundle size increase: ~1.2 MB (minimal city index only)
- Fully offline, correct DST handling via `timezone` package

**Key insight:** The `lat_lng_to_timezone` package already solves timezone detection, eliminating the need to store timezone in the city database or ask users to enter it manually.

---

## Problem Statement

### Business Context

**User Need:** Prayer times feature needs manual location selection to handle:
- Users without GPS enabled or unreliable GPS (poor signal, privacy concern)
- Users wanting prayer times for a different city (travel planning, diaspora users abroad)
- Users wanting to override auto-detected location with a home city

**Current Limitation:** App only reads device GPS → no fallback; users in locations without strong GPS signals or privacy-conscious users cannot access prayer times.

**Product Owner Decision:** Add manual city selection to the Prayer feature roadmap (targeted for Phase 1 release, 2026-09).

### Functional Requirements

1. **Automatic Detection (Existing)** — GPS-based location detection should continue working
2. **Manual City Search (NEW)** — User can search cities by name and select from results
3. **Manual Coordinates (NEW)** — User can enter lat/lng directly (expert mode)
4. **Timezone Inference (NEW)** — Timezone must be automatically determined from location, NOT from device timezone or user input
5. **Prayer Time Calculation** — Prayer times recalculated when location changes; times shown in the **location's timezone**, not device timezone
6. **Persistence** — Selected location saved across app restarts

### Technical Constraints

| Constraint | Reason | Impact |
|-----------|--------|--------|
| **Fully offline** | App requirement; no network dependency | No reverse-geocoding, no online timezone APIs; must bundle city data |
| **Accurate timezones** | Prayer times depend on correct timezone including DST | Cannot infer from device OS; must use validated IANA database |
| **DST handling** | Same prayer time at different device offsets on DST transition days | Timezone conversion must happen at each instant, not once per day |
| **Minimal bundle size** | App already 8.8 MB; mobile deployment sensitive | City database < 1.5 MB; no duplicate timezone data |
| **Device privacy** | No unneeded network or telemetry | GPS usage only when user opts in; city selections never sent anywhere |
| **Performance** | App must remain responsive, especially city search | City DB indexed for fast lookup on older devices |

### Success Criteria

- ✅ User can search for a city and see results ranked by relevance
- ✅ Selecting a city saves the location and recomputes prayer times
- ✅ Prayer times **differ** when user switches between cities in different timezones
- ✅ Prayer times **are correct** for the selected city's timezone (verified against external reference like IslamicFinder)
- ✅ DST transitions handled correctly (times jump 1 hour on DST boundaries, not 2x calculations)
- ✅ Manual coordinate entry works for unmapped locations
- ✅ Bundle size increase < 1.5 MB
- ✅ City search latency < 500ms on oldest supported device
- ✅ No compile-time errors; all tests pass; no regressions in existing prayer features

### Scope: IN ✅

- Manual city selection from a curated offline database (~15k cities)
- Automatic timezone inference via `lat_lng_to_timezone` package
- Manual lat/lng coordinate entry
- Persistence of selected location in SharedPreferences
- Prayer time recalculation for new location
- Basic error handling (invalid coordinates, lookup failures)
- Unit + integration tests for core flows

### Scope: OUT ❌

- Favorite/recent cities list (Phase 2)
- Map-based location picker (Phase 2)
- Timezone offset display (Phase 2)
- Additional prayer times (Suhur, Iftar, Tahajjud — separate feature)
- Reverse-geocoding device GPS to city name (not in scope)
- Online fallback geocoding (violates offline requirement)
- Analytics/telemetry on location selections
- Language-specific city names (English only)

### Critical Guarantees (Must Not Break)

1. **Correctness:** Prayer times must be mathematically correct for the selected location's timezone at that moment
   - Failure mode: Silent wrong times (undetectable by user, damages app trust)
   - Mitigation: Regression test suite with cross-checks vs IslamicFinder

2. **Offline:** No network requests for city data, timezone data, or prayer calculations
   - Failure mode: App unusable on flights, poor connectivity
   - Mitigation: All data bundled; no API calls in critical path

3. **Consistency:** Times must change when timezone changes (no stale cache)
   - Failure mode: User switches cities, times don't update
   - Mitigation: Computed property (not cached) for timezone inference

4. **Privacy:** No unsolicited network traffic or data collection
   - Failure mode: User's location choices sent anywhere
   - Mitigation: Only device local storage; no analytics

### Known Limitations & Mitigations

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| City DB covers 99%, not 100% of the world | Some very small towns missing | Manual coordinate entry as fallback; doc: "If city not found, enter coordinates" |
| IANA timezone rules change 2–3x/year | Cached timezone data can drift from OS | Auto-update `timezone` package with releases; monitor package repo |
| Ambiguous city names (e.g., "Springfield" in 5 US states) | User confusion during search | Disambiguate with region/state; rank by population; show "Springfield, Massachusetts" not just "Springfield" |
| Coordinate → timezone lookup can fail in disputed borders | Edge case (e.g., Kashmir, South Sudan) | Fallback to UTC; document in LEARNINGS.md |

### Assumptions

1. **`lat_lng_to_timezone` package is reliable** — Used by thousands of projects; we trust its offline coordinate→timezone mapping
2. **`timezone` package is maintained** — Annual IANA updates are standard; package is well-established
3. **`adhan` package calculation is correct** — Already in production (existing prayer feature); not changing
4. **User will search for major cities** — 15k entry database is sufficient for 99% of use cases
5. **Device has geolocation hardware or can accept manual input** — No assumption of always-on GPS

---

---

## Architecture Decision: Auto-Inferred Timezone

### Why This Approach

**Dependencies Already in pubspec.yaml:**
```yaml
adhan: ^2.1.1                      # Prayer calculations
timezone: ^0.9.4                   # IANA DB + DST handling
lat_lng_to_timezone: ^0.1.3        # Lat/Lng → IANA timezone (offline)
```

These packages handle everything. The solution is:

1. **User selects a location** (GPS, city search, or manual coordinates)
   → Obtain `latitude` and `longitude`

2. **Automatic timezone detection**
   → `lat_lng_to_timezone(latitude, longitude)` → returns IANA string (e.g., `"Asia/Karachi"`)

3. **Pass to prayer calculation**
   → `PrayerTimesRepository.timesFor(location, date)` uses the auto-detected timezone

4. **DST handled automatically**
   → `timezone` package applies IANA rules for that location

**No manual timezone entry, no timezone database to maintain.**

### Why NOT the Previous Over-Engineered Approach

❌ Bundling timezone data in city database (redundant)
❌ Storing IANA codes with each city (maintenance burden)
❌ Falling back to manual timezone entry (user error vector)
❌ Extra 1.2 MB of duplicate data

---

## Data Model

### Domain Entity: GeoLocation

**Current definition (unchanged storage):**
```dart
class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,  // Display name: "Karachi, Pakistan" or "Custom Location"
    this.source,  // 'auto' (GPS) or 'manual' (city search or coordinates)
  });

  final double latitude;
  final double longitude;
  final String? label;
  final String source;

  /// Timezone automatically detected from coordinates (computed property).
  /// Never stored — always derived on-demand. Returns IANA string or 'UTC' fallback.
  String get timezoneIana {
    try {
      return latLngToTimezone(latitude, longitude);
    } catch (_) {
      // Fallback for edge cases (extreme latitudes, etc.)
      return 'UTC';
    }
  }

  @override
  List<Object?> get props => [latitude, longitude, label, source];
}
```

**Persistence (SharedPreferences — unchanged):**
```dart
_kLat = 'prayer_lat'
_kLon = 'prayer_lon'
_kLabel = 'prayer_label'
_kSource = 'prayer_source'  // NEW
```

No timezone stored anywhere.

### Domain Entity: CityLocation

**For search results only — never persisted:**
```dart
class CityLocation extends Equatable {
  const CityLocation({
    required this.name,          // "Karachi"
    required this.country,       // "Pakistan"
    required this.latitude,      // 24.8607
    required this.longitude,     // 67.0011
    this.region,                 // "Sindh" (optional, for disambiguation)
    this.population,             // 15400000 (for relevance ranking)
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String? region;
  final int? population;

  /// Convert to a persistent GeoLocation with display label.
  GeoLocation toGeoLocation() {
    final parts = [name, region, country].where((p) => p != null).join(', ');
    return GeoLocation(
      latitude: latitude,
      longitude: longitude,
      label: parts,
      source: 'manual',
    );
  }

  @override
  List<Object?> get props => [name, country, latitude, longitude];
}
```

### City Database: Minimal Schema

**SQLite table (bundled, read-only):**
```sql
CREATE TABLE cities (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  country TEXT NOT NULL,
  country_code TEXT,
  region TEXT,                 -- State/province (nullable)
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  population INTEGER,          -- For search ranking (nullable)
  UNIQUE(name, country, region)
);

CREATE INDEX idx_name ON cities(name);
```

**Data:** ~15,000 entries (1.2 MB compressed)
- All cities with population > 5,000 OR administrative center
- One city per significant timezone per country
- Hand-curated & verified against local references

**Drift table definition:**
```dart
@DataClassName('CityRecord')
class Cities extends Table {
  IntColumn get id => integer().primaryKey();
  TextColumn get name => text();
  TextColumn get country => text();
  TextColumn get countryCode => text().nullable();
  TextColumn get region => text().nullable();
  RealColumn get latitude => real();
  RealColumn get longitude => real();
  IntColumn get population => integer().nullable();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {name, country, region},
  ];
}
```

---

## UX Flow

### User Journey 1: Automatic GPS (Current)

```
Home Screen / Prayer Widget
  ↓
  [📍 Tap location icon]
  ↓
  Request GPS permission → Auto-detect coordinates
  ↓
  latLngToTimezone(lat, lng) → "Asia/Karachi" ✅
  ↓
  Save location + source='auto'
  ↓
  Display: "Device Location" | Prayer times in location's TZ
```

### User Journey 2: Manual City Search (NEW)

```
Home Screen
  ↓
  [⚙️ Settings / Prayer Location]
  ↓
  Choose: ◉ Use Device Location  ○ Select City Manually
  ↓
  [Search city...               ]
  User types: "lond"
  ↓
  Results:
  • London, UK                  (population: 9M, region: England)
  • Londonderry, UK             (population: 83k, region: Northern Ireland)
  • Londonberry, Canada         (smaller city, ranked lower)
  ↓
  User taps: "London, UK"
  ↓
  latLngToTimezone(51.5074, -0.1278) → "Europe/London" ✅
  ↓
  Save location (lat, lng, label, source='manual')
  ↓
  Display: "London, UK" | Prayer times in Europe/London TZ
            └─ GMT+0 / BST (shown in device timezone offset)
```

### User Journey 3: Manual Coordinates (NEW - Expert Mode)

```
Prayer Settings → [Manual Coordinates]
  ↓
  Latitude:  [24.8607____]
  Longitude: [67.0011____]
  ↓
  User enters coordinates → [Save]
  ↓
  latLngToTimezone(24.8607, 67.0011) → "Asia/Karachi" ✅
  ↓
  Save location (lat, lng, label="Custom Location", source='manual')
  ↓
  Display: "Custom Location" | Prayer times in inferred TZ
```

---

## Implementation Plan

### Phase 1: Foundation (Core Manual Location + Auto Timezone)

**Goal:** Add manual city selection + ensure timezone inference works correctly.

#### Step 1.1: Enhance Domain Models

**File:** `lib/features/prayer_times/domain/entities/geo_location.dart`

```dart
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.source = 'auto',  // 'auto' (GPS) or 'manual' (city search / coordinates)
  });

  final double latitude;
  final double longitude;
  final String? label;
  final String source;

  /// Timezone automatically inferred from coordinates (offline, no storage).
  String get timezoneIana {
    try {
      return latLngToTimezone(latitude, longitude);
    } catch (_) {
      return 'UTC';
    }
  }

  @override
  List<Object?> get props => [latitude, longitude, label, source];
}
```

**File:** `lib/features/prayer_times/domain/entities/city_location.dart` (NEW)

```dart
import 'geo_location.dart';

class CityLocation extends Equatable {
  const CityLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.region,
    this.population,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String? region;
  final int? population;

  GeoLocation toGeoLocation() {
    final parts = [name, region, country].whereType<String>().join(', ');
    return GeoLocation(
      latitude: latitude,
      longitude: longitude,
      label: parts,
      source: 'manual',
    );
  }

  @override
  List<Object?> get props => [name, country, latitude, longitude];
}
```

#### Step 1.2: Add City Repository Interface

**File:** `lib/features/prayer_times/domain/repositories/city_repository.dart` (NEW)

```dart
import '../entities/city_location.dart';

abstract interface class CityRepository {
  /// Search cities by name. Returns up to 20 results ranked by:
  /// 1. Name match score (prefix > substring)
  /// 2. Population (larger first)
  /// Returns empty list if no results.
  Future<List<CityLocation>> searchCities(String query);

  /// Get a specific city by ID.
  Future<CityLocation?> getCityById(int id);
}
```

#### Step 1.3: Implement City Data Layer

**File:** `lib/core/database/tables.dart` (ADD to existing)

```dart
@DataClassName('CityRecord')
class Cities extends Table {
  IntColumn get id => integer().primaryKey();
  TextColumn get name => text();
  TextColumn get country => text();
  TextColumn get countryCode => text().nullable();
  TextColumn get region => text().nullable();
  RealColumn get latitude => real();
  RealColumn get longitude => real();
  IntColumn get population => integer().nullable();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {name, country, region},
  ];
}
```

**File:** `lib/core/database/app_database.dart` (UPDATE)

```dart
// Add to @DriftDatabase annotation:
include: {'tables.drift'}

// Add to class:
late final Lazy<CityDao> cityDao = Lazy(() => CityDao(this));
```

**File:** `lib/features/prayer_times/data/datasources/cities_local_datasource.dart` (NEW)

```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class CitiesLocalDataSource {
  CitiesLocalDataSource(this._database);
  
  final AppDatabase _database;

  Future<List<CityRecord>> searchCities(String query, {int limit = 20}) async {
    // Full-text search: name prefix match + country contains + rank by population
    final q = query.toLowerCase();
    return await _database.select(_database.cities)
      .where((c) => 
        c.name.lower().like('$q%') |
        c.country.lower().like('%$q%')
      )
      .orderBy([
        (c) => OrderingTerm(expression: c.population, mode: OrderingMode.desc),
      ])
      .limit(limit)
      .get();
  }

  Future<CityRecord?> getCityById(int id) async {
    return await (_database.select(_database.cities)
      ..where((c) => c.id.equals(id)))
      .getSingleOrNull();
  }
}
```

**File:** `lib/features/prayer_times/data/repositories/city_repository_impl.dart` (NEW)

```dart
import '../../domain/entities/city_location.dart';
import '../../domain/repositories/city_repository.dart';
import '../datasources/cities_local_datasource.dart';

class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl(this._localDataSource);

  final CitiesLocalDataSource _localDataSource;

  @override
  Future<List<CityLocation>> searchCities(String query) async {
    if (query.isEmpty) return [];
    final records = await _localDataSource.searchCities(query);
    return records
      .map((r) => CityLocation(
        name: r.name,
        country: r.country,
        latitude: r.latitude,
        longitude: r.longitude,
        region: r.region,
        population: r.population,
      ))
      .toList();
  }

  @override
  Future<CityLocation?> getCityById(int id) async {
    final record = await _localDataSource.getCityById(id);
    if (record == null) return null;
    return CityLocation(
      name: record.name,
      country: record.country,
      latitude: record.latitude,
      longitude: record.longitude,
      region: record.region,
      population: record.population,
    );
  }
}
```

#### Step 1.4: Update Prayer Times Repository

**File:** `lib/features/prayer_times/data/repositories/prayer_times_repository_impl.dart` (UPDATE)

```dart
// UPDATE: Add source tracking to persistence
static const String _kSource = 'prayer_source';

@override
Future<LocationResult> acquireLocation() async {
  final result = await _locationProvider.current();
  final loc = result.location;
  if (result.status == LocationStatus.ok && loc != null) {
    await _prefs.setDouble(_kLat, loc.latitude);
    await _prefs.setDouble(_kLon, loc.longitude);
    if (loc.label != null) {
      await _prefs.setString(_kLabel, loc.label!);
    }
    await _prefs.setString(_kSource, 'auto');  // NEW
  }
  return result;
}

// UPDATE: Use location's automatic timezone inference
@override
DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) {
  final params = _method.getParameters()
    ..madhab = _madhab
    ..highLatitudeRule = adhan.HighLatitudeRule.twilight_angle;

  final adhan.PrayerTimes times;
  try {
    times = adhan.PrayerTimes(
      adhan.Coordinates(location.latitude, location.longitude),
      adhan.DateComponents.from(date),
      params,
      utcOffset: Duration.zero,
    );
  } catch (_) {
    return null;
  }

  // NEW: Convert times using location's inferred timezone
  final tzData = tz.getLocation(location.timezoneIana);
  
  return DailyPrayerTimes(
    fajr: _convertToLocalTz(times.fajr, tzData),
    sunrise: _convertToLocalTz(times.sunrise, tzData),
    dhuhr: _convertToLocalTz(times.dhuhr, tzData),
    asr: _convertToLocalTz(times.asr, tzData),
    maghrib: _convertToLocalTz(times.maghrib, tzData),
    isha: _convertToLocalTz(times.isha, tzData),
    location: location,
    date: date,
  );
}

// NEW: Helper to convert UTC instant to local wall-clock time in a timezone
DateTime _convertToLocalTz(DateTime utc, tz.Location tzLocation) {
  final localized = tz.TZDateTime.from(utc, tzLocation);
  // Return as plain DateTime (non-UTC) so instant matches display
  return DateTime(
    localized.year,
    localized.month,
    localized.day,
    localized.hour,
    localized.minute,
  );
}
```

#### Step 1.5: Add City Search Cubit

**File:** `lib/features/prayer_times/presentation/cubit/city_search_state.dart` (NEW)

```dart
part of 'city_search_cubit.dart';

abstract class CitySearchState extends Equatable {
  const CitySearchState();

  @override
  List<Object?> get props => [];
}

class CitySearchInitial extends CitySearchState {
  const CitySearchInitial();
}

class CitySearchLoading extends CitySearchState {
  const CitySearchLoading();
}

class CitySearchResults extends CitySearchState {
  const CitySearchResults({required this.cities});

  final List<CityLocation> cities;

  @override
  List<Object?> get props => [cities];
}

class CitySearchEmpty extends CitySearchState {
  const CitySearchEmpty();
}

class CitySearchError extends CitySearchState {
  const CitySearchError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
```

**File:** `lib/features/prayer_times/presentation/cubit/city_search_cubit.dart` (NEW)

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/city_location.dart';
import '../../domain/repositories/city_repository.dart';

part 'city_search_state.dart';

class CitySearchCubit extends Cubit<CitySearchState> {
  CitySearchCubit(this._cityRepository) : super(const CitySearchInitial());

  final CityRepository _cityRepository;

  Future<void> searchCities(String query) async {
    if (query.isEmpty) {
      emit(const CitySearchEmpty());
      return;
    }

    emit(const CitySearchLoading());
    try {
      final cities = await _cityRepository.searchCities(query);
      if (cities.isEmpty) {
        emit(const CitySearchEmpty());
      } else {
        emit(CitySearchResults(cities: cities));
      }
    } catch (e) {
      emit(CitySearchError(message: e.toString()));
    }
  }

  void reset() {
    emit(const CitySearchInitial());
  }
}
```

#### Step 1.6: Update DI (GetIt)

**File:** `lib/core/di/injector.dart` (UPDATE)

```dart
// In configureDependencies():

// Repositories
getIt.registerSingleton<CityRepository>(
  CityRepositoryImpl(CitiesLocalDataSource(_appDatabase)),
);

// Cubits
getIt.registerFactory<CitySearchCubit>(
  () => CitySearchCubit(getIt<CityRepository>()),
);
```

#### Step 1.7: City Search UI Widget

**File:** `lib/features/prayer_times/presentation/widgets/city_search_field.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/city_location.dart';
import '../cubit/city_search_cubit.dart';

class CitySearchField extends StatefulWidget {
  const CitySearchField({
    required this.onCitySelected,
    this.hintText = 'Search city...',
  });

  final void Function(CityLocation) onCitySelected;
  final String hintText;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    context.read<CitySearchCubit>().searchCities(query);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    context.read<CitySearchCubit>().reset();
                  },
                )
              : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: _onSearch,
        ),
        const SizedBox(height: 12),
        BlocBuilder<CitySearchCubit, CitySearchState>(
          builder: (context, state) {
            if (state is CitySearchInitial || state is CitySearchLoading) {
              return const SizedBox();
            }

            if (state is CitySearchEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No cities found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }

            if (state is CitySearchError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${state.message}'),
              );
            }

            if (state is CitySearchResults) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: state.cities.length,
                itemBuilder: (context, index) {
                  final city = state.cities[index];
                  final displayName = [city.name, city.region, city.country]
                    .whereType<String>()
                    .join(', ');

                  return ListTile(
                    title: Text(displayName),
                    subtitle: city.population != null
                      ? Text('Population: ${city.population}')
                      : null,
                    onTap: () {
                      widget.onCitySelected(city);
                      _controller.clear();
                      context.read<CitySearchCubit>().reset();
                    },
                  );
                },
              );
            }

            return const SizedBox();
          },
        ),
      ],
    );
  }
}
```

#### Step 1.8: Prayer Location Settings Sheet

**File:** `lib/features/prayer_times/presentation/widgets/prayer_location_sheet.dart` (NEW or UPDATE)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/city_location.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../cubit/prayer_times_cubit.dart';
import 'city_search_field.dart';

class PrayerLocationSheet extends StatefulWidget {
  const PrayerLocationSheet();

  @override
  State<PrayerLocationSheet> createState() => _PrayerLocationSheetState();
}

class _PrayerLocationSheetState extends State<PrayerLocationSheet> {
  late bool _useDeviceLocation;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    final currentLocation = context.read<PrayerTimesRepository>().location;
    _useDeviceLocation = (currentLocation?.source ?? 'auto') == 'auto';
    _latController = TextEditingController(
      text: currentLocation?.latitude.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: currentLocation?.longitude.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _onCitySelected(CityLocation city) {
    final location = city.toGeoLocation();
    context.read<PrayerTimesRepository>().acquireLocation(); // TODO: save location instead
    // TODO: Implement saveLocation method on repository
    Navigator.pop(context);
  }

  void _onManualCoordinates() {
    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      final location = GeoLocation(
        latitude: lat,
        longitude: lng,
        label: 'Custom Location',
        source: 'manual',
      );
      // TODO: Save location via repository
      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid coordinates')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prayer Times Location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Option 1: Device GPS
            RadioListTile<bool>(
              title: const Text('Use Device Location (GPS)'),
              subtitle: const Text('Automatically detect from device'),
              value: true,
              groupValue: _useDeviceLocation,
              onChanged: (v) {
                setState(() => _useDeviceLocation = v ?? true);
              },
            ),
            if (_useDeviceLocation) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'GPS will detect your location and infer the timezone automatically.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Trigger acquireLocation
                  },
                  child: const Text('Enable GPS & Save Location'),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Option 2: Search City
            RadioListTile<bool>(
              title: const Text('Select City Manually'),
              value: false,
              groupValue: _useDeviceLocation,
              onChanged: (v) {
                setState(() => _useDeviceLocation = v ?? false);
              },
            ),
            if (!_useDeviceLocation) ...[
              const SizedBox(height: 8),
              CitySearchField(
                onCitySelected: _onCitySelected,
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Option 3: Manual Coordinates
            Text(
              'Manual Coordinates (Expert)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '24.8607',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '67.0011',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onManualCoordinates,
                child: const Text('Save Coordinates'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Step 1.9: Update Prayer Times Repository Interface

**File:** `lib/features/prayer_times/domain/repositories/prayer_times_repository.dart` (UPDATE)

```dart
abstract interface class PrayerTimesRepository {
  GeoLocation? get location;

  /// Acquire (via GPS) and persist the device location.
  Future<LocationResult> acquireLocation();

  /// NEW: Save a manually selected location.
  Future<void> saveLocation(GeoLocation location);

  /// Prayer times calculation (unchanged).
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date);
}
```

**File:** `lib/features/prayer_times/data/repositories/prayer_times_repository_impl.dart` (UPDATE)

```dart
@override
Future<void> saveLocation(GeoLocation location) async {
  await _prefs.setDouble(_kLat, location.latitude);
  await _prefs.setDouble(_kLon, location.longitude);
  if (location.label != null) {
    await _prefs.setString(_kLabel, location.label!);
  }
  await _prefs.setString(_kSource, location.source);
}
```

---

### Phase 1 Acceptance Criteria

- [ ] City database generated (1.2 MB, ~15k entries)
- [ ] `CityLocation` domain entity created
- [ ] `CityRepository` interface + implementation working
- [ ] `lat_lng_to_timezone` integration tested
- [ ] `GeoLocation.timezoneIana` computed correctly for test cities
- [ ] Prayer times calculated in location's timezone (not device TZ)
- [ ] Manual city search UI built + search returns results
- [ ] Manual coordinate entry working
- [ ] City selection saves location + recomputes prayer times
- [ ] **Timezone changes when user switches cities** (regression test)
- [ ] Bundle size increase verified < 1.5 MB
- [ ] All unit tests pass
- [ ] Manual testing: Select city in different TZ, verify times differ from device TZ times

---

### Phase 2: Polish & Enhancements (Future)

**Out of scope for Phase 1 but noted for reference:**

- [ ] Timezone offset label display (e.g., "GMT+5")
- [ ] Favorited/recent cities quick-access
- [ ] Retry logic for GPS permission denial
- [ ] Better error messaging (no GPS, invalid coordinates)
- [ ] Map picker as alternative to coordinates
- [ ] "Current city" vs "Home city" distinction

---

## Testing Strategy

### Unit Tests

**File:** `test/features/prayer_times/domain/entities/geo_location_test.dart` (NEW)

```dart
void main() {
  group('GeoLocation.timezoneIana', () {
    test('Karachi returns Asia/Karachi', () {
      const location = GeoLocation(latitude: 24.8607, longitude: 67.0011);
      expect(location.timezoneIana, 'Asia/Karachi');
    });

    test('London returns Europe/London', () {
      const location = GeoLocation(latitude: 51.5074, longitude: -0.1278);
      expect(location.timezoneIana, 'Europe/London');
    });

    test('New York returns America/New_York', () {
      const location = GeoLocation(latitude: 40.7128, longitude: -74.0060);
      expect(location.timezoneIana, 'America/New_York');
    });

    test('Invalid coordinates fallback to UTC', () {
      const location = GeoLocation(latitude: 999, longitude: 999);
      expect(location.timezoneIana, 'UTC');
    });
  });
}
```

**File:** `test/features/prayer_times/data/repositories/prayer_times_repository_test.dart` (UPDATE)

```dart
// Existing tests + new:

test('Prayer times differ when timezone changes', () {
  final karachi = GeoLocation(latitude: 24.8607, longitude: 67.0011);
  final london = GeoLocation(latitude: 51.5074, longitude: -0.1278);

  final date = DateTime(2026, 8, 8);
  
  final karachiTimes = repository.timesFor(karachi, date);
  final londonTimes = repository.timesFor(london, date);

  expect(karachiTimes?.fajr, isNotNull);
  expect(londonTimes?.fajr, isNotNull);
  
  // Fajr times should differ significantly
  expect(
    karachiTimes!.fajr.difference(londonTimes!.fajr).inHours.abs(),
    greaterThan(3),
  );
});

test('DST transitions handled correctly', () {
  // New York, during EDT (DST)
  final summer = DateTime(2026, 6, 15);
  final summerTimes = repository.timesFor(nyLocation, summer);

  // New York, during EST (standard time)
  final winter = DateTime(2026, 12, 15);
  final winterTimes = repository.timesFor(nyLocation, winter);

  // Offset should differ by ~1 hour (DST)
  expect(
    summerTimes!.fajr.difference(winterTimes!.fajr).inMinutes.abs(),
    closeTo(60, 5),
  );
});
```

**File:** `test/features/prayer_times/data/repositories/city_repository_test.dart` (NEW)

```dart
void main() {
  group('CityRepository.searchCities', () {
    test('Search returns cities matching query', () async {
      final cities = await repository.searchCities('karachi');
      expect(cities, isNotEmpty);
      expect(cities.first.name, 'Karachi');
      expect(cities.first.country, 'Pakistan');
    });

    test('Search returns empty for nonexistent city', () async {
      final cities = await repository.searchCities('xyzabc');
      expect(cities, isEmpty);
    });

    test('Results ranked by population', () async {
      final cities = await repository.searchCities('new');
      // New York (population ~8M) should rank before Newton (smaller)
      expect(
        cities[0].population ?? 0,
        greaterThanOrEqualTo(cities[1].population ?? 0),
      );
    });

    test('Search is case-insensitive', () async {
      final lower = await repository.searchCities('london');
      final upper = await repository.searchCities('LONDON');
      expect(lower.first.name, upper.first.name);
    });
  });
}
```

### Integration Tests

**File:** `test/features/prayer_times/presentation/prayer_location_sheet_test.dart` (NEW)

```dart
void main() {
  group('PrayerLocationSheet', () {
    testWidgets('Displays location options', (tester) async {
      await tester.pumpWidget(testApp);
      
      // Verify UI
      expect(find.text('Prayer Times Location'), findsOneWidget);
      expect(find.text('Use Device Location (GPS)'), findsOneWidget);
      expect(find.text('Select City Manually'), findsOneWidget);
    });

    testWidgets('City search returns results', (tester) async {
      await tester.pumpWidget(testApp);
      
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'karachi');
      await tester.pumpAndSettle();
      
      expect(find.text('Karachi, Pakistan'), findsOneWidget);
    });

    testWidgets('Selecting city updates prayer times', (tester) async {
      await tester.pumpWidget(testApp);
      
      await tester.tap(find.text('Karachi, Pakistan'));
      await tester.pumpAndSettle();
      
      // Verify location saved and prayers updated
      final repo = getIt<PrayerTimesRepository>();
      expect(repo.location?.label, contains('Karachi'));
    });
  });
}
```

---

## Key Decisions & Rationale

### Decision 1: Auto-Inferred Timezone (Not Stored)

**Why:** 
- `lat_lng_to_timezone` package already handles this offline
- No need to duplicate timezone data in city database
- Eliminates manual timezone entry → no user error
- Cleaner: lat/lng is the source of truth, timezone is derived

**Trade-off:** 
- Timezone lookup happens on-demand (negligible performance cost)
- Relies on `lat_lng_to_timezone` package being maintained

### Decision 2: Minimal City Index (~15k entries)

**Why:**
- Covers 99% of use cases (all major cities + administrative centers)
- Only 1.2 MB compressed
- Fully offline
- Good search UX for common locations

**Trade-off:**
- Some small cities/towns won't be in database
- Mitigation: manual coordinate entry for edge cases

### Decision 3: SharedPreferences for Location Persistence

**Why:**
- Already used for prayer settings
- Simple key-value storage sufficient
- No structured queries needed

**Trade-off:**
- Limited to single location (no favorites/history)
- Phase 2 enhancement: Drift table for favorites

### Decision 4: DST Handled by `timezone` Package

**Why:**
- Package is battle-tested, updated annually
- Automatically applies IANA rules for any location
- Eliminates manual offset calculations

**Trade-off:**
- Depends on external package maintenance
- Mitigation: monitor package updates

---

## Bundle Size Breakdown

| Component | Current | New | Delta |
|-----------|---------|-----|-------|
| SQLite city DB (compressed) | — | 1.2 MB | +1.2 |
| Code + Drift schema | — | 0.1 MB | +0.1 |
| No timezone data stored | — | 0 MB | 0 |
| **Total Bundle** | 8.8 MB | ~10.1 MB | +1.3 MB ✅ |

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Silent wrong prayer times** (critical) | 🔴 Critical | Regression test suite: compare times across timezones; cross-check vs IslamicFinder |
| **`lat_lng_to_timezone` dependency fails** | 🟡 Medium | Fallback to 'UTC'; document in LEARNINGS.md; monitor package |
| **City DB becomes outdated** | 🟡 Medium | Version city DB; update annually; owner reviews new candidates |
| **IANA timezone data diverges from OS** | 🟠 Low | Update `timezone` package regularly; follow release notes |
| **Search too slow on old devices** | 🟠 Low | Test on oldest device; add SQLite FTS5 if needed |
| **Ambiguous city names (multiple "Springfield")** | 🟠 Low | Display "City, Region, Country"; rank by population |

---

## Rollout Plan

### Pre-Implementation
- [ ] Decision: Approve city data source (recommend: GeoNames dump, curated)
- [ ] Generate city database & verify accuracy vs local references (Karachi, London, New York, etc.)
- [ ] Owner sign-off on bundle size increase

### Implementation (Phase 1)
- [ ] Follow steps 1.1–1.9 above
- [ ] Build & test
- [ ] Code review

### Testing
- [ ] Unit tests pass
- [ ] Integration tests on physical device (test DST transitions if available)
- [ ] Manual QA: try city selection, verify times update

### Deployment
- [ ] Merge to develop
- [ ] Include in next release
- [ ] Document in release notes

---

## Future Enhancements (Phase 2+)

- **Timezone offset label** — show "GMT+5" or "UTC-5 (EDT)"
- **Favorite cities** — quick-access to saved locations
- **Map picker** — tap on map instead of searching
- **Suhur/Iftar/Tahajjud** — additional timings beyond the 6 prayers
- **Import/export** — backup + restore locations
- **Travel mode** — temporarily switch to a different timezone

---

## References

- **Current prayer times implementation:** `lib/features/prayer_times/`
- **Packages:**
  - `adhan` (v2.1.1) — Prayer time calculations
  - `timezone` (v0.9.4) — IANA database + DST handling
  - `lat_lng_to_timezone` (v0.1.3) — Coordinate → timezone inference (offline)
- **Drift docs:** https://drift.simonbinder.eu/
- **GeoNames:** https://www.geonames.org/ (data source for city index)

---

## Questions for Owner

1. **City data source:** Approve GeoNames dump (curated to 15k entries)?
2. **Bundle size:** +1.3 MB acceptable?
3. **Timeline:** Needed before Phase 1 release?
4. **Manual entries:** Allow coordinate entry for expert users?
5. **Favorites:** Should Phase 2 include saved location history?

---

**Document Status:** Draft Planning | **Last Updated:** 2026-08-08 | **Next:** Owner review → Implementation kickoff
