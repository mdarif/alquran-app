# AGENTS.md — Al Quran (Flutter app)

Context for Codex working in this repo. Companion data repo:
`../alquran-data` (read its `HANDOFF.md` and `AGENTS.md` for how `quran.db` is built).

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
- Platform folders `android/` and `ios/` are **committed** (since 2026-06) — the
  app ships native home-screen widget code that must live in version control.
  Build artifacts stay ignored via each folder's own `.gitignore`. The unused
  desktop/web runners (`linux/ macos/ windows/ web/`) are still generated-only.
- Drift codegen (`*.g.dart`) is **not** committed — run `build_runner`.
- The KFGQPC font, the Reading↔Detailed toggle, and the Page/Juz/Hizb/Ruku
  navigation UI are all **done**. The Page/Juz/Hizb/Ruku "Jump to" lives behind
  `FeatureFlags.advancedNavigation`, which is **off for the first release** — v1
  ships **Surah-only** by owner decision (reading-first home); flip the flag to
  resurface the rest. The DB carries all the indices.

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
- **Hindi translation** is Suhel Farooq Khan & Saifur Rahman Nadwi (Tanzil
  edition `hi.hindi`, not on QUL — sourced via the AlQuran Cloud API which
  mirrors Tanzil; see `../alquran-data/config/sources.yaml`). Earlier builds
  used Maulana Azizul Haque al-Umari. Urdu is Junagarhi. Reader order:
  Urdu → Hindi → English.
- **Licensing** of translations/fonts is UNVERIFIED — clear before any release
  (see `../alquran-data/HANDOFF.md`).

## Data schema (from ../alquran-data/pipeline/schema.sql)

`surahs(id, name_arabic, name_english, revelation_place, total_ayahs)` ·
`ayahs(id, surah_id, ayah_number, text_arabic_uthmani, text_arabic_indopak,
page_number, juz_number, hizb_number, rub_el_hizb, ruku_number, sajda)` ·
`resources(id, slug, type, language_code, name, native_name, author, direction,
sort_order, default_on, license, source_url)` ·
`translations(id, ayah_id, resource_id, text_content)` · `db_meta(key, value)`.

114 surahs / 6236 ayahs; ur + hi + en translations complete; all nav indices populated.

## Editions — several per language, keyed by slug

A language may carry several editions (two Hindi translations), so **nothing may
key on `language_code`** — it groups only. The stable identity is
`resources.slug` (`ur-junagarhi`, `hi-suhel-farooq-nadwi`).

- **Never persist `resources.id`.** The data pipeline assigns it from
  `cur.lastrowid`, so every id shifts when an edition is added to or reordered
  in its `sources.yaml`. A saved id silently points at a different edition after
  the next data refresh. The reader's saved selection holds slugs, migrated once
  from the old language codes (`reader_settings_repository_impl.dart`).
- **`sort_order` is a GLOBAL display order**, not per-language: it fixes the
  reading order under each verse (Urdu first) and the picker's grouping falls
  out of it. Ordering by id instead reshuffles the page when an edition is
  inserted upstream.
- `Ayah.translations` is keyed by **slug**, so bundled and downloaded editions
  share one map.

### Downloadable editions

Bundled editions live in `quran.db`. Downloaded ones live in **`editions.db`, a
separate file** — and this is not a preference. `db_seeder.dart` overwrites
`quran.db` wholesale whenever the bundled version marker changes, so anything
written into it is **destroyed on the next app update**, silently, with the
reader simply finding their downloads gone. Never merge the two.

Artifacts come from `alquran-data/pipeline/build_editions.py` → Cloudflare R2:
`catalogue.json` plus one gzipped SQLite file per slug (~4:1; Hindi 3.2 MB →
612 KB). `lib/core/editions_config.dart` holds the base URL, overridable with
`--dart-define=EDITIONS_CATALOGUE_URL` for staging.

Install verifies **two** sha256 digests — the transferred file before expanding
it, and the expanded DB before installing — and checks the artifact declares the
slug that was asked for. A truncated download is otherwise indistinguishable
from a short edition and would render blank verses with no error. Nothing
installs on a mismatch. → `test/features/translations/edition_install_test.dart`

Rows are addressed by `(slug, surah, ayah)`, never the global ayah id: an
installed edition outlives the build that produced it.

**Live and wired.** The R2 bucket is provisioned (`editions.alquranreader.com`)
and the catalogue routinely lists more editions than are bundled — that's the
intended, ongoing state, not a gap to close. `TranslationsPage` opens from the
Home overflow's "Translations" entry (`home_overflow_menu.dart`).
`TranslationsCubit` is an app-lifetime singleton (registered in
`injector.dart`, provided at `app.dart`'s root, like `RemindersCubit`/
`ThemeCubit`): `FeatureFlags.proactiveTranslationSync` fetches the catalogue
once at launch, so a newly published edition needs no app-store release to
reach readers. A small unseen-edition dot on that menu entry
(`TranslationsState.hasUnseenEditions`, cleared by `markCatalogueSeen()` when
the screen is actually opened — never by a silent background `load()`) is the
passive discovery signal for it. An edition retracted from the catalogue stays
installed and usable for readers who already have it; it just stops appearing
under "Available for download" for everyone else.
