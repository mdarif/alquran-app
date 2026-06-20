# Al Quran — Flutter App

Ultra-lightweight, fully-offline Quran reader for **Al Marfa Technologies**
(almarfa.co). Reads the bundled `quran.db` seed database compiled by the
[`alquran-data`](../alquran-data) pipeline — no backend, zero recurring compute.

Implements PRD v1.1.1 MVP foundations: single-script Uthmani/Madani Arabic with
Urdu + Hindi translations, built on Clean Architecture (Cubit + Drift + GetIt).

## What's in this scaffold

- **Clean Architecture** with a Flutter-free domain layer (PRD 7.1).
- **Drift** over the bundled SQLite asset; the prepopulated DB is unpacked to
  writable storage on first launch (migration is a no-op — tables already exist).
- **GetIt** DI graph (`lib/core/di/injector.dart`).
- **Surah list → ayah reader**: tap a surah to read its ayahs in Detailed mode
  (Arabic stacked over Urdu + Hindi) with pinch-to-zoom font scaling (PRD 4.1).

```
lib/
  main.dart · app.dart
  core/
    database/   app_database.dart (Drift) · tables.dart
    di/         injector.dart (GetIt)
    theme/      app_theme.dart
  features/
    surahs/     domain · data · presentation (list)
    reader/     domain · data · presentation (ayah reader)
assets/
  db/quran.db   bundled seed DB (from the alquran-data pipeline)
  fonts/        drop KFGQPC_Uthmanic_Hafs.ttf here (see fonts/README.md)
```

## Prerequisites

- Flutter SDK ≥ 3.22 (Dart ≥ 3.4). Check with `flutter doctor`.

## First-time setup

This repo contains the Dart source, the bundled DB, and config — but **not** the
generated platform folders or Drift codegen. Generate them once:

```bash
cd ~/code/alquran-app

# 1. Generate android/ios (etc.) runners. flutter create preserves existing
#    files (lib/, pubspec.yaml) and only adds what's missing.
flutter create --org com.almarfa --project-name al_quran --platforms=android,ios .

# 2. Fetch packages
flutter pub get

# 3. Generate Drift code (creates lib/core/database/app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 4. Run
flutter run
```

> If the analyzer flags a missing `app_database.g.dart` before step 3, that's
> expected — it's produced by build_runner.

## Notes

- **Arabic font:** the app currently falls back to the platform Arabic font.
  Add `KFGQPC_Uthmanic_Hafs.ttf` to `assets/fonts/` and uncomment the `fonts:`
  block in `pubspec.yaml` to use the proper Madani face (PRD 4.1).
- **Bundle size / NFRs:** ship arm64-only via per-ABI splits (PRD NFR-1); profile
  cold start on low-spec Android (NFR-3).
- **Deferred (PRD backlog):** Page/Juz/Hizb/Ruku navigation UI, Reading↔Detailed
  toggle, audio, bookmarks, dark mode, search. The DB already carries the
  page/juz/hizb/rub/ruku/sajda indices for when those land.
- **Licensing:** translation/font licences are unverified — see the alquran-data
  HANDOFF before any public release.
