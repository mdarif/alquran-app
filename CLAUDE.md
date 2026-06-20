# CLAUDE.md — Al Quran (Flutter app)

Context for Claude Code working in this repo. Companion data repo:
`../alquran-data` (read its `HANDOFF.md` and `CLAUDE.md` for how `quran.db` is built).

## What this is

**Al Quran** — an ultra-lightweight, fully-offline Quran reader by **Al Marfa
Technologies** (almarfa.co). It bundles `assets/db/quran.db` (compiled by the
`alquran-data` pipeline) and reads it locally — no backend, zero recurring compute.

Product spec: "Al Quran Mobile App — Master PRD v1.1.1" (owner's Google Drive).
This app implements the PRD MVP. Earlier drafts called the product "AlMarfa360
Quran" — the correct name everywhere is **"Al Quran"**.

## MVP scope (PRD §3) — do not expand without owner sign-off

- **In:** single-script Uthmani/Madani Arabic (KFGQPC Hafs); Urdu + Hindi
  translations; navigation by Surah / Page / Juz / Hizb / Ruku (Rub + Sajda
  stored too); pinch-to-zoom (hard accessibility requirement); dual viewport
  (Reading = Arabic only, Detailed = Arabic + Urdu + Hindi); fully offline.
- **Out (backlog):** IndoPak script, English/Roman-Urdu, audio, bookmarks,
  last-read, dark mode, tajweed, full-text search, tafsir, word-by-word,
  exact-Mushaf rendering.

## Architecture (PRD §7.1 — follow strictly)

- **Clean Architecture.** Each feature under `lib/features/<name>/` with
  `domain/` (pure Dart — NO Flutter/Drift imports), `data/`, `presentation/`.
  No cross-feature imports.
- **Stack:** Cubit (`flutter_bloc`) for state · Drift over SQLite for data ·
  GetIt for DI (`lib/core/di/injector.dart`).
- **One-way state:** UI → Cubit → repository → Drift; immutable state, `const`
  constructors, `final` fields.

```
lib/
  main.dart · app.dart
  core/
    database/  app_database.dart (Drift, opens bundled asset) · tables.dart
    di/        injector.dart (GetIt graph)
    theme/     app_theme.dart
  features/
    surahs/  domain · data · presentation  (Surah list screen)
    reader/  domain · data · presentation  (ayah reader, Detailed mode + pinch-zoom)
```

## Current state (scaffold — built 2026-06)

Implemented and present:
- Drift `AppDatabase` mapping the real schema (surahs, ayahs, resources,
  translations, db_meta); prepopulated-asset unpacking on first launch;
  migration is a deliberate **no-op** (tables already exist in the seed DB).
- GetIt wiring; Surah list (all 114) → tap → ayah reader showing Arabic over
  Urdu + Hindi, with pinch-to-zoom (20–48pt) and +/- font buttons.

NOT done yet / next up:
- **Not compile-checked** — built in an environment without Flutter. Run
  `flutter analyze` first; expect minor fixes.
- Platform folders (`android/`, `ios/`) are **not** committed — generate with
  `flutter create` (see below). They're gitignored.
- Drift codegen (`*.g.dart`) is **not** committed — run `build_runner`.
- Navigation UI for Page/Juz/Hizb/Ruku, the Reading↔Detailed toggle, and the
  KFGQPC font are not done. The DB already carries all the indices for them.

## Run / build

```bash
flutter create --org com.almarfa --project-name al_quran --platforms=android,ios .
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart
flutter run
```

Commands:
- Analyze: `flutter analyze`
- Test: `flutter test`
- Regenerate Drift code after editing tables: `dart run build_runner build --delete-conflicting-outputs`

## Key decisions & gotchas

- **Package id:** `com.almarfa.alquran` (org `com.almarfa`, project `al_quran`).
- **Drift column mapping:** `build.yaml` sets `case_from_dart_to_sql: snake_case`
  so camelCase getters (e.g. `nameArabic`) map to the DB's snake_case columns
  (`name_arabic`). Keep that, or queries break against the prepopulated DB.
- **Prepopulated DB:** `db_seeder.dart` (`ensureSeedDatabase`, called from
  `configureDependencies` before the DB opens) copies the bundled asset to the
  app docs dir and **re-copies whenever the version marker changes**, so an
  updated `quran.db` actually reaches users. `AppDatabase(File)` just opens that
  file; `migration.onCreate` is intentionally empty — do NOT add `m.createAll()`,
  the tables/data already exist. **After replacing `assets/db/quran.db`, run
  `make seed-version`** to refresh `assets/db/quran.db.version` (= `db_meta.built_at`),
  or the new data won't be detected on devices that already ran the app.
- **Arabic font:** the `fonts:` block in `pubspec.yaml` is commented out so the
  build stays green. Add `assets/fonts/KFGQPC_Uthmanic_Hafs.ttf` and uncomment
  to use the Madani face. Until then it falls back to the platform Arabic font.
- **Arabic text** includes QPC's end-of-ayah number glyph (e.g. `١`). Decide in
  the data repo (`prepare_sources.py`) whether to strip it; the app just renders
  what's in the DB.
- **Hindi translation** is Maulana Azizul Haque al-Umari (substituted for the
  PRD's unavailable Farooq Khan/Ahmed). Urdu is Junagarhi.
- **Licensing** of translations/fonts is UNVERIFIED — clear before any release
  (see `../alquran-data/HANDOFF.md`).

## Data schema (from ../alquran-data/pipeline/schema.sql)

`surahs(id, name_arabic, name_english, revelation_place, total_ayahs)` ·
`ayahs(id, surah_id, ayah_number, text_arabic_uthmani, text_arabic_indopak,
page_number, juz_number, hizb_number, rub_el_hizb, ruku_number, sajda)` ·
`resources(id, type, language_code, name, author, license, source_url)` ·
`translations(id, ayah_id, resource_id, text_content)` · `db_meta(key, value)`.

114 surahs / 6236 ayahs; ur + hi translations complete; all nav indices populated.
