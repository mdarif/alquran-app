# Al Quran — Flutter App

Ultra-lightweight, fully-offline Quran reader for **Al Marfa Technologies**
(almarfa.co). Reads the bundled `quran.db` seed database compiled by the
[`alquran-data`](../alquran-data) pipeline — no backend, zero recurring compute.

Implements PRD v1.1.1 MVP foundations: single-script Uthmani/Madani Arabic with
Urdu + Hindi translations, built on Clean Architecture (Cubit + Drift + GetIt).

## Features

The living inventory of what the app does today. **Keep this current:** when a
feature lands, ships, or flips a flag, update the matching row in the same commit.
Source of truth for gating is `lib/core/feature_flags.dart` — if a flag value here
disagrees with that file, the file wins. Status: **Shipped** = visible in a default
build · **Shipped (flag on)** = shipped but behind a `FeatureFlags` constant that's
currently `true`, so it can be turned off without code surgery · **Dark** = built
but gated off behind a `FeatureFlags` constant that's `false` · **Roadmap** =
planned, not built. _Last updated: 2026-06-25._

**Core reading**
- Surah browsing (all 114) → ayah reader — *Shipped*
- Uthmani Arabic in the matched KFGQPC Hafs (UthmanicHafs1 Ver18) font — *Shipped*
- Urdu (Junagarhi) + Hindi (Tanzil `hi.hindi`) translations, order Urdu → Hindi — *Shipped*
- Dual viewport: Reading (Arabic only) ↔ Detailed (Arabic + translations) — *Shipped*
- Pinch-to-zoom + font ± controls (accessibility requirement) — *Shipped*
- Last-read resume banner — *Shipped (flag on)* (`lastReadBanner` = true; off hides the banner, reader still records position)
- Scroll-to-top on long surahs — *Shipped*
- IndoPak script option (Noorehuda font, authentic `text_indopak`) — *Shipped (flag on)* (`indopakScript` = true)

**Theming**
- "Light of Day" time-adaptive, prayer-aware reading surface + Reading-light toggle — *Shipped (flag on)* (`lightOfDay` = true; off → one static light and the toggle is hidden on Home + reader)

**Prayer times** (`prayerTimes` = true)
- Offline calc (Karachi method + Shafi Asr, hard-wired per creed), next-prayer app-bar pill, all-five-prayers sheet, forbidden-prayer-window cue — *Shipped (flag on)*
- Drives the prayer-AWARE tint of Light of Day (snaps to real Fajr/Sunrise/Asr/Maghrib/Isha). Flag off → Light of Day falls back to clock-hour phases.

**Reminders**
- Sunnah reminders — local-notification nudges at exact times, settings sheet, and a battery-optimization reliability hint (one-tap OS exemption so OEMs don't drop alarms) — *Shipped (flag on)* (`sunnahReminders` = true; off hides the button and skips all scheduling)

**Hijri date**
- Home dateline + the date block in the prayer-times sheet (Maghrib-rolled when prayer times are on, civil date otherwise) — *Shipped (flag on)* (`hijriDate` = true; off hides both)

**Audio**
- Tap-a-verse recitation (Mishary Rashid Alafasy), streamed + cached, in-app — *Shipped (flag on)* (`audioRecitation` = true). ⚠️ On pending on-device playback + audio-source licensing sign-off — confirm before release.

**Behind dark flags (built, not surfaced in v1)**
- Home-screen widgets — Android Next Prayer + "Today's prayers", iOS WidgetKit PrayerWidget — *Dark* (`homeScreenWidgets` = false). The Dart flag stops the app feeding the widgets; the native widget targets still exist in the build (see caveat).
- Advanced navigation — Page / Juz / Hizb / Ruku "Jump to" sheet — *Dark* (`advancedNavigation` = false)

**Roadmap (not built)**
- Hifz / page-wise memorization mode
- Companion Quran website (next project)

> **Caveat:** translation/font/audio-source licensing is unverified — clear before
> any release (see the alquran-data HANDOFF). Dark features need their flag flipped
> and a rebuild to appear. The `homeScreenWidgets` flag only stops the app feeding
> the OS widgets — to keep them out of v1 entirely, also drop the iOS widget
> extension target and the Android `<receiver>` registrations from the build.

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

This repo contains the Dart source, the bundled DB, config, and the committed
`android/` + `ios/` runners (they carry the native home-screen widget code) — but
**not** Drift codegen or the desktop/web runners. Set up once:

```bash
cd ~/code/alquran-app

# 1. Fetch packages
flutter pub get

# 2. Generate Drift code (creates lib/core/database/app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 3. Run
flutter run
```

> `android/` and `ios/` are committed, so no `flutter create` is needed for them.
> To (re)generate the unused desktop/web runners, run
> `flutter create --org com.almarfa --project-name al_quran .`.

> If the analyzer flags a missing `app_database.g.dart` before step 3, that's
> expected — it's produced by build_runner.

## Notes

- **Arabic font:** the app currently falls back to the platform Arabic font.
  Add `KFGQPC_Uthmanic_Hafs.ttf` to `assets/fonts/` and uncomment the `fonts:`
  block in `pubspec.yaml` to use the proper Madani face (PRD 4.1).
- **Bundle size / NFRs:** ship arm64-only via per-ABI splits (PRD NFR-1); profile
  cold start on low-spec Android (NFR-3).
- **Feature status:** see the **Features** section above — it's the maintained
  inventory of what's shipped, what's built-but-dark-flagged, and what's roadmap.
- **Licensing:** translation/font licences are unverified — see the alquran-data
  HANDOFF before any public release.
