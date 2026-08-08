# Prayer Section: Manual/Auto Location + Extra Timings

## Context

The Prayer tab today can only get a location one way: device GPS via `geolocator`. If the
user denies permission, has location services off, or is on a device with a poor fix, there
is **no fallback at all** — `PrayerTimesRepositoryImpl.location` returns null, the cubit
emits `PrayerTimesState.unset()`, and the entire prayer surface degrades to an "Enable
location" button. There is no city picker, no coordinate entry, and no location data of any
kind in `assets/`.

There is also a latent correctness bug waiting behind any manual-location feature: every
prayer time is converted through `_deviceLocal` ([prayer_times_repository_impl.dart:112](lib/features/prayer_times/data/repositories/prayer_times_repository_impl.dart#L112)),
so times are always rendered on the **phone's** clock. The moment a user can choose a city
in another timezone, that produces silently wrong times.

Alongside this, the owner wants the Prayer tab to earn its place as an experience: a
next-prayer hero, a compact 5-prayer timeline, and Suhur End / Iftar / Tahajjud tiles.

Hard constraint from the owner: **do not grow the bundle.** Two earlier documents
(`docs/prayer-times-manual-location-plan.md` and its validation report) landed on +3.5 MB.
This plan gets the same capability for roughly **+0.6 MB** by deleting the two expensive
line items:

- **`lat_lng_to_timezone` (2.3 MB) is not needed.** GeoNames ships an IANA timezone per
  city, so the city record carries its own zone. GPS locations use the device zone — which
  is correct by construction, because GPS means the user is physically there.
- **No second SQLite/Drift database.** A packed binary asset decoded in Dart avoids a
  seeder, Drift codegen, a version marker, and a Makefile target.

Owner decisions taken during planning:

| Decision | Choice |
|---|---|
| City data | Packed gzipped asset, ~26k cities (GeoNames pop ≥ 15k + all capitals) |
| Cross-timezone city | Show the **city's own** wall clock; **pause** salat alerts with a visible, one-tap-reversible note |
| Redesign scope | Location + Suhur/Iftar/Tahajjud + timeline. **No** Qibla, **no** monthly timetable |
| Fiqh | Suhur End = Fajr exactly · Iftar = Maghrib exactly · Tahajjud = Maghrib + ⅔·(Fajr−Maghrib) · **no user-facing minute offsets** |

---

## Creed guardrails (Salafi / Ahle-Hadith) — non-negotiable

This section governs every other section. If any step below appears to conflict with it,
this section wins and the step is dropped.

1. **Karachi method + Shafi (standard) Asr stay hard-wired**, exactly as they are at
   [prayer_times_repository_impl.dart:34-36](lib/features/prayer_times/data/repositories/prayer_times_repository_impl.dart#L34),
   with their existing comment block intact. Nothing in this plan adds a calculation knob,
   a method picker, a madhab picker, or per-prayer minute offsets. Hanafi Asr is never
   offered, defaulted to, or mentioned in any UI string.

2. **The named trap: do not auto-select a calculation method from the chosen country.**
   This is the standard behaviour of nearly every prayer-times library and app — pick
   Karachi for Pakistan, Umm al-Qura for Saudi, Egyptian for Egypt, ISNA for North America,
   and so on. `adhan` exposes all of them, and adding a city picker makes wiring
   country → method feel like the obviously "correct" polish. **It is not.** It would
   silently hand some users a non-Salafi timetable purely because of where they searched.
   The method is a fixed constant and the country field of a `City` feeds only the display
   label and search ranking — never the calculation. Add a code comment saying so at the
   point where `City` is converted to `GeoLocation`, so a future contributor doesn't
   "fix" it.

3. **Only latitude, longitude, and timezone may vary by location.** That is the entire
   contract of this feature.

4. **Extra timings follow the strict positions** fixed above: Suhur ends at true dawn
   (= Fajr, no precautionary subtraction), Iftar at sunset (= Maghrib, no delay), Tahajjud
   labelled as the start of the last third of the night. No "Ihtiyat" minutes anywhere.

5. **The forbidden-time windows stay.** The three "No Nafl Prayer" spans in
   `DailyPrayerTimes.forbiddenWindows` are a deliberate Ahle-Hadith-consistent feature and
   must survive the Phase 4 redesign untouched — they are explicitly listed as unchanged
   in step 5 of that phase.

6. **Nothing devotional is added beyond what is listed here.** No Qibla compass, no
   tasbih, no du'a lists, no dhikr counters, no mosque finder. Scope is location accuracy
   plus the three timings above.

---

## The timezone insight (the spine of this plan)

`tz.TZDateTime` **extends `DateTime`**. A `TZDateTime` in `Europe/London` reports `.hour`
as London's wall clock *and* compares as a true instant against `DateTime.now()`.

So changing what `_toLocal` returns fixes cross-timezone correctness with almost no API
churn:

- `formatPrayerTime(t)` reads `t.hour`/`t.minute` → renders the **city's** clock, unchanged.
- `nextAfter(now)`, `currentSalahAt`, `forbiddenAt` use `isAfter`/`isBefore` → compare
  **instants**, correct across zones.
- Countdown `at.difference(now)` → a real elapsed duration, correct **including** DST
  transitions falling inside the countdown.
- `PrayerNotificationsCubit` → `tz.TZDateTime.from(fireAt, tz.local)` already takes an
  instant, so it keeps working.

The `timezone` package is already a dependency and already initialized in
[main.dart:35](lib/main.dart#L35). **Zero new packages, zero new bytes** for full DST-aware,
travel-aware correctness.

---

## Phase 0 — Spike (do this first, before any code)

Build the asset and **measure**, so the bundle number is a fact rather than the estimate
that sank the previous plan.

1. `tool/build_cities.py` — download GeoNames `cities15000.zip` + `countryInfo.txt`,
   filter to pop ≥ 15 000 plus every national/admin1 capital, and emit
   `assets/geo/cities.bin.gz`.
2. Report: uncompressed size, gzipped size, row count, and the measured AAB delta from
   `make aab` before/after.
3. **Gate:** if the gzipped asset exceeds ~800 KB, raise the population floor (25k/50k) and
   re-measure before proceeding.

Record format (little-endian, one header + N fixed records + a string pool):

```
header:  magic "ALQC" | u8 version | u32 rowCount | u16 tzCount | u16 countryCount
pools:   tz ids (IANA strings) | country names | admin1 names   -- interned, indexed
record:  u32 nameOff | u32 asciiOff | u16 countryIdx | u16 adminIdx
         i32 lat*1e5 | i32 lon*1e5 | u32 population | u16 tzIdx
```

Decoded lazily — **only** when the location picker opens — and dropped afterwards. Zero
startup cost, zero RAM until used. This mirrors the discipline in
[db_seeder.dart](lib/core/database/db_seeder.dart) without needing a second database.

GeoNames is **CC BY 4.0** → an attribution line must be added to the About page
([about_page.dart](lib/features/navigation/presentation/pages/about_page.dart)), alongside
the existing licence notices.

---

## Phase 1 — Timezone-correct core

### 1.1 `GeoLocation` gains two fields
[geo_location.dart](lib/features/prayer_times/domain/entities/geo_location.dart)

```dart
final String? timezoneId;          // IANA, e.g. 'Asia/Karachi'; null => device zone
final LocationSource source;       // enum { device, city, coordinates }
```

`timezoneId` null is the meaningful GPS case, not a failure. Keep the existing file-header
comment about never reverse-geocoding — it is still true.

### 1.2 Repository resolves the zone
[prayer_times_repository_impl.dart](lib/features/prayer_times/data/repositories/prayer_times_repository_impl.dart)

Replace the injected `DateTime Function(DateTime utc) _toLocal` with an injected
**zone resolver**, `tz.Location Function(GeoLocation)`, defaulting to:

```dart
static tz.Location _zoneFor(GeoLocation l) {
  final id = l.timezoneId;
  if (id == null) return tz.local;
  try { return tz.getLocation(id); } catch (_) { return tz.local; }
}
```

Then, inside `timesFor`, keep `utcOffset: Duration.zero` (that decision and its long
comment stay) and convert each instant with a minute-truncating helper that stays an exact
instant:

```dart
DateTime _inZone(DateTime utc, tz.Location z) {
  final t = tz.TZDateTime.from(utc, z);
  return tz.TZDateTime(z, t.year, t.month, t.day, t.hour, t.minute);
}
```

This is *strictly better* for tests than today's `toLocal` injection: they pass a fixed
zone instead of an identity function, and remain machine-independent.

New persistence keys beside `prayer_lat`/`prayer_lon`/`prayer_label`: `prayer_tz`,
`prayer_source`. **Migration:** both absent ⇒ `source = device`, `timezoneId = null` — which
reproduces today's exact behaviour for every existing install. Also fix the existing bug at
line 57 where a null label never clears a stale one.

Interface additions in
[prayer_times_repository.dart](lib/features/prayer_times/domain/repositories/prayer_times_repository.dart):

```dart
Future<void> saveLocation(GeoLocation location);
Future<void> clearLocation();
```

### 1.3 Initialize timezones earlier
[main.dart](lib/main.dart) currently calls `tzdata.initializeTimeZones()` inside
`_initReminders()`, **after** `configureDependencies()`. Hoist it to the first line of
`main()` (still inside its try/catch) so no prayer computation can ever race it. The
`_zoneFor` fallback to `tz.local` covers the failure path regardless.

### 1.4 Extra timings — pure domain math, zero bytes
[daily_prayer_times.dart](lib/features/prayer_times/domain/entities/daily_prayer_times.dart)

Add computed getters beside the existing `solarNoon` / `forbiddenWindows`:

```dart
DateTime get suhurEnd => fajr;                    // strict: dawn is dawn
DateTime get iftar    => maghrib;
/// Start of the last third of the night. Needs TOMORROW's Fajr, so this takes it.
DateTime lastThirdFrom(DateTime nextFajr) =>
    maghrib.add(Duration(
      microseconds: (nextFajr.difference(maghrib).inMicroseconds * 2) ~/ 3,
    ));
```

`lastThirdFrom` deliberately takes tomorrow's Fajr rather than reusing today's — using
today's is a common off-by-a-day bug in prayer apps. `PrayerTimesCubit` already fetches
tomorrow's schedule in `_compute` (line 76), so plumb that through into state.

---

## Phase 2 — City data layer

Living under `lib/features/prayer_times/`, following clean-architecture boundaries
(`domain/` stays pure Dart — no Flutter, no asset access).

| File | Role |
|---|---|
| `domain/entities/city.dart` | `City { name, asciiName, country, admin1, lat, lon, population, timezoneId }` + `toGeoLocation()` |
| `domain/repositories/city_repository.dart` | `Future<List<City>> search(String q, {int limit})` · `Future<City?> nearest(double lat, double lon)` |
| `data/cities/packed_city_index.dart` | Decodes `assets/geo/cities.bin.gz`; lazy, cached, disposable |
| `data/repositories/city_repository_impl.dart` | Search ranking + nearest-city scan |

**Search ranking** (all in-memory, ~26k rows ⇒ well under the 500 ms bar even on old
hardware): fold to ASCII + lowercase, then exact name > prefix > word-prefix > substring,
tie-broken by population descending. Debounce input ~200 ms in the cubit.

`nearest(lat, lon)` is a linear haversine scan (~26k iterations, <5 ms) and serves the
manual-coordinates path: it supplies the IANA zone for coordinates the user typed in.

**Reuse note:** the home Surah search already implements a fold-and-rank helper
(`quickMatch`, mirrored from al-quran-web) in the surahs feature — match its normalization
behaviour rather than inventing a second convention.

DI in [injector.dart](lib/core/di/injector.dart): `registerLazySingleton<CityRepository>`
(lazy is essential — the asset must not be touched at startup), and
`registerFactory<CitySearchCubit>` under the existing `// Cubits (new instance per screen)`
block. Register **unconditionally**, per the standing rule at injector.dart:256 that DI is
never gated on a feature flag.

---

## Phase 3 — Location UX

### Entry points (existing UX preserved)

The home-screen pill is the start of the journey and its happy path must not change.

- **Pill, located** ([next_prayer_pill.dart](lib/features/prayer_times/presentation/widgets/next_prayer_pill.dart)):
  unchanged — tap still switches to the Prayer tab via `onOpenPrayerTab`.
- **Pill, no location:** today it fires a GPS request straight from the icon button and
  shows a snackbar on denial. Keep the fast path, but on `denied` / `deniedForever` /
  `serviceOff`, **push the location page** instead of dead-ending in a snackbar. Strictly
  additive.
- **Prayer tab, no location:** `_NoLocation` in
  [prayer_page.dart:66](lib/features/navigation/presentation/pages/prayer_page.dart#L66)
  becomes the two-card chooser from the reference design — "Allow Location" (GPS) and "Set
  Manually" (city picker) — built from `MushafPalette` tokens via `Theme.of(context)`, not
  the reference's cream palette.
- **Prayer tab, located:** a location row at the bottom of the schedule → same page.

### New page
`lib/features/prayer_times/presentation/pages/prayer_location_page.dart` — a plain
`Navigator.push(MaterialPageRoute)` (the app has a single root Navigator, no go_router):

1. Current location card + "Use my location" (GPS).
2. Search field → live results as `City, Admin1, Country`.
3. "Enter coordinates" expander (lat/lon, validated to ±90/±180), resolving its zone via
   `nearest()`.

New keys in [widget_keys.dart](lib/core/testing/widget_keys.dart), matching house style:
`prayerLocationPage`, `prayerLocationRow`, `prayerLocationUseGps`, `prayerCitySearchField`,
and `static Key cityResult(int index) => Key('city-result-$index');`

New icons in [app_icons.dart](lib/core/theme/app_icons.dart) — each **must** keep its
trailing `// symbol_name` comment, since `tools/icon/subset_symbols.py` re-derives the
subset from it: `location_on`, `my_location`, `edit_location_alt`, plus glyphs for the
Suhur / Iftar / Tahajjud tiles. Then run `python3 tools/icon/subset_symbols.py` and commit
the regenerated `assets/fonts/MaterialSymbolsRounded.ttf`.

### Cross-timezone alert pause
When `location.timezoneId` resolves to a zone whose current offset differs from `tz.local`:

- `PrayerNotificationsCubit._reschedule()` schedules nothing and surfaces
  `zoneMismatch: true` in its state.
- The Prayer tab and the salat section of
  [reminders_settings_page.dart](lib/features/navigation/presentation/pages/reminders_settings_page.dart)
  render one line — *"Alerts paused — this city is in a different timezone than your
  phone."* — with a **Turn on anyway** action persisting an override pref.
- Compare **offsets at the current instant**, not zone ids: `Asia/Kolkata` vs
  `Asia/Calcutta` are the same zone, and two different ids can share an offset.

---

## Phase 4 — Prayer tab redesign

All of this lives in
[prayer_times_sheet.dart](lib/features/prayer_times/presentation/widgets/prayer_times_sheet.dart)
(809 lines), which is shared by the Prayer tab **and** the modal sheet reached when the pill
has no `onOpenPrayerTab`. Add a `compact` flag so the modal keeps today's lean layout while
the tab gets the full treatment — do not fork the widget.

Composition, top to bottom:

1. Header + Hijri line — **unchanged**.
2. `_PrayerFocusCard` hero with live countdown — **unchanged** (including the
   `_ForbiddenFocusCard` swap).
3. **New** `_PrayerTimeline` — five dots on a rule, filled for the active prayer, name +
   time beneath (reference screenshot 6). Pure layout over `times.schedule`.
4. **New** `_ExtraTimingsRow` — three tiles: Suhur End / Iftar / Tahajjud (screenshot 5),
   using the Phase 1.4 getters.
5. Full list with Sunrise and the "No Nafl Prayer" windows — **unchanged**. This is
   genuinely differentiating; it stays exactly as it is.
6. **New** location row → `PrayerLocationPage`.

`formatPrayerTime` currently omits AM/PM by design, justified because prayer names
disambiguate. That justification does not hold for a Tahajjud tile reading `1:16`. Add a
sibling `formatClockTime(t, {required bool use24h})` used **only** by the three tiles,
honouring `MediaQuery.alwaysUse24HourFormat`. Leave `formatPrayerTime` untouched so all
existing widget tests keep passing.

Colours come from `Theme.of(context).colorScheme` and
`theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02)` — never the reference
screenshots' cream literals. Spacing follows the house 8/12/16/20/24 convention.

---

## Phase 5 — Home-screen widgets

`FeatureFlags.homeScreenWidgets` is **false**, so nothing here ships in this release — but
the payload contract must not silently rot.

[widget_payload.dart](lib/core/home_widget/widget_payload.dart) documents that `at` strings
are device-local wall clock with no offset, and both `PrayerWidgetProvider.kt` and
`PrayerWidget.swift` parse them that way. Once times are `TZDateTime`,
`toIso8601String()` starts emitting an offset and would break that parse.

Minimal, correct fix: bump `currentSchemaVersion` to 2 and emit **explicit UTC** `at`
values, with `locationLabel` and `timezoneId` alongside. Update both native parsers to read
UTC and render in the payload's zone. Cheap now; a field bug report later if skipped.

---

## Test plan

Testing is required alongside the change, not after it.

**Blast radius — 6 hand-written fakes implement `PrayerTimesRepository`** and all need the
two new methods:
`test/features/navigation/prayer_page_test.dart:14` ·
`test/features/prayer_times/next_prayer_pill_test.dart:15` ·
`test/features/prayer_times/prayer_times_routing_test.dart:16` ·
`test/features/prayer_times/prayer_notifications_cubit_test.dart:14` ·
`test/features/prayer_times/hijri_date_line_test.dart:14` ·
and **`lib/main_prayer_diag.dart:27`** (a fake living in production source, easy to miss).

New / updated tests:

- **Timezone correctness** (`prayer_times_repository_test.dart`): same coordinates rendered
  in two zones differ by the expected offset; times for a location whose zone ≠ device zone
  come out on the *city's* clock. Existing Abu Dhabi fixture retained.
- **DST boundary**: Europe/London across the spring-forward and autumn fall-back dates, and
  a US transition — asserting no doubled or skipped hour, and that a countdown spanning the
  transition reports the true elapsed duration.
- **Migration**: prefs holding only `prayer_lat`/`prayer_lon` (an existing v1 install)
  produce byte-identical times to today.
- **Extra timings** (`daily_prayer_times_test.dart`): `suhurEnd == fajr`,
  `iftar == maghrib`, and `lastThirdFrom` sits exactly ⅔ into the night — including a case
  where tomorrow's Fajr differs from today's, so the off-by-a-day bug is caught.
- **City index**: decode round-trip; search ranks `Karachi` first for `"kar"`; ASCII
  folding matches accented names; `nearest()` returns the correct city for known
  coordinates; search latency over the full asset stays under budget.
- **Widget tests**: `PrayerLocationPage` renders the three modes; picking a city persists
  and recomputes; the zone-mismatch banner appears only on mismatch and the override clears
  it; the timeline and the three tiles render for a fixed `initialNow`.
- **Regression**: pill happy path unchanged; `_NoLocation` still offers GPS;
  `prayer_notifications_cubit_test` still schedules normally when zones match.
- **Creed guard (new, deliberate)**: a test asserting that the same date and coordinates
  produce identical times regardless of the `City`'s country field — i.e. selecting
  Makkah, Cairo, or Toronto never changes the calculation method away from Karachi/Shafi.
  This is the one guardrail a future contributor is most likely to break while trying to
  be helpful, so it gets an explicit failing test rather than a comment alone.

## Verification

```bash
make gen        # only if Drift tables changed — this plan adds none
make ci         # format-check + analyze --fatal-warnings + test
make aab        # measure the real bundle delta against the Phase 0 baseline
```

Then, on device (owner runs the app himself):

1. Deny location → Prayer tab shows the two-card chooser; pick a city → times appear.
2. Pick a same-timezone city → alerts stay armed; pick London from Karachi → times show
   London's clock and the alerts-paused note appears.
3. Cross-check Karachi and London against a published timetable, to the minute.
4. Confirm the home pill's tap-to-Prayer-tab behaviour is untouched.

Finally: record the packed-asset format, the `TZDateTime` insight, and the
timezone-init ordering hazard in `LEARNINGS.md`, and close out the corresponding entries in
`docs/quality-backlog.md`.

---

## Related documents — do not implement from these

Two earlier planning documents remain in `docs/` **for history only**. Both are marked
superseded at the top of the file, and both describe an approach this plan deliberately
rejects (`lat_lng_to_timezone`, a bundled city SQLite/Drift database, +3.5 MB):

- `docs/prayer-times-manual-location-plan.md`
- `docs/prayer-times-plan-validation-report.md`

**This file is the only current spec.** If anything in those two documents contradicts
this one, this one wins.
