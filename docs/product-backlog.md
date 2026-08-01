# Product backlog — features (shipped + missing)

Feature-level status across the Al Quran ecosystem (this app, `../alquran-data`,
`../al-quran-web`), from a reader's perspective. Distinct from
`quality-backlog.md`, which tracks bugs/UX rough edges in features that already
exist. Update this file as features ship or scope decisions change; don't let
it drift from `FeatureFlags` / the actual code.

## Shipped

- **Reading + Detailed viewport modes** — Arabic-only vs Arabic + Urdu/Hindi/English, pinch-to-zoom (20–48pt), +/- font buttons.
- **Surah navigation** — full list of 114, search (mirrors web quickMatch).
- **Audio recitation** — tap-a-verse + continuous full-surah autoplay (cross-surah), Alafasy, self-hosted CDN stream+cache. Foreground-only (see below).
- **IndoPak script** — Noorehuda font, authentic Quran.com `text_indopak`, flag ON.
- **Multiple translations, multi-language** — Urdu (Junagarhi, default), Hindi (Suhel Farooq Khan/Nadwi), English (Hilali & Khan) bundled; the edition model (data repo, 2026-07-28) supports several editions per language and on-demand downloads via a Translations screen reading a CDN catalogue.
- **Continue reading** — resumes the exact verse, in the viewport you left off in; the open stamp waits for a dwell so a glance can't overwrite a deep position.
- **Light of Day** — time-adaptive theming (pillar 1 of 3; shipped as the "dark mode" answer instead of a literal toggle).
- **Prayer times sheet** — Karachi method + Shafi Asr (hard-wired, no other madhab options), Hijri date shown.
- **Reader virtualization** — page-chunked lazy list, ~17-31ms open time.
- **Bookmarks** — ayah-level, multiple, with a bookmarks screen (`AyahBookmarkRepository`, verse address only — no notes/tags yet).
- **Sunnah reminders** — local notifications for Al-Kahf (Friday), White Days, Ashura, Arafah, Dhul Hijjah; the Al-Kahf one routes into the reader and resumes where you left off.

## Built but flagged OFF for v1

- **Juz / Hizb / Ruku / Page "Jump to" navigation** — fully built, DB carries all indices (page 1–604, juz 1–30, hizb 1–60, rub 1–240, ruku 1–558, 15 sajdas). Gated behind `FeatureFlags.advancedNavigation`, OFF by owner decision (v1 = Surah-only, reading-first home). **Cheapest re-enable in this whole list — no new work, just flip the flag** when ready to bring it back.
- **Home-screen prayer widgets** — Android (`PrayerWidgetProvider`, `PrayerScheduleWidgetProvider`) and iOS WidgetKit targets are BUILT and committed, gated behind `FeatureFlags.homeScreenWidgets` (OFF for v1: the app never feeds them). Note the native targets still ship in the build — to keep them out of the OS widget gallery entirely, drop the iOS extension target and the Android `<receiver>` registrations.

## Missing — no ingestion/implementation started anywhere in the 3 repos

- **Tafsir** — → **Roadmap #1**. No data source ingested, no schema, no reader UI. Would need: pick a tafsir edition (QUL/QuranEnc carry tafsir resources), extend `alquran-data` schema (new `tafsir` resource type + table, parallel to `translations`), then app + web UI to surface it per-ayah.
- **Word-by-word translation** — Arabic word-by-word text is already used internally (QUL `quran-script/312` powers ayah reconstruction), but no per-word *translation* is ingested or rendered. Needs its own QUL source + schema + UI (word-tap popovers).
- **Tajweed (color-coded pronunciation rules)** — → **Roadmap #7**. Not started; needs a tajweed-annotated Arabic source (QUL has tajweed-rule Uthmani exports) and rendering support (likely a different font/markup approach than the current KFGQPC text).
- **Exact-Mushaf page rendering** (line-for-line matching the print Mushaf, not flowing text) — not started. Current reader flows paragraphs; page number is tracked but line-breaks aren't reproduced.
- **Full-text / verse-text search** — not started in the app. Web has surah-*name* search only (quickMatch), not verse-content search.
- **Bookmark notes / naming** — ayah bookmarks themselves shipped (see above); naming or annotating them has not. The web backlog's local-storage/privacy decision still applies if these ever sync.

## Deferred to a later release (explicit owner decisions, not forgotten)

- **Lock-screen / background audio** — see `quality-backlog.md` #11; foreground-only today.
- **Tablet-specific layout** — no tablet UI; phone layout stretched. Deferred to release-after-next.
- **Hifz (memorization) page mode** — optional page-wise mode without zoom/pan, roadmap item, not started.

## Roadmap — owner's next-version list (2026-08-01)

Ordered as the owner raised them, not by priority. Each notes where the work
actually lands, since most of these start in `../alquran-data`, not here.

1. **Tafsir in the Detailed view** — a per-ayah tafsir surfaced alongside the
   translations. Biggest of the seven: pick an edition first (QUL/QuranEnc carry
   tafsir resources; an Urdu tafsir matching the audience, and the *creed* of the
   tafsir matters more than its availability), then extend the data pipeline with
   a `tafsir` resource type + table parallel to `translations`, then the reader
   UI. Tafsir entries are long-form and often span a range of ayat rather than
   one — that shapes both the schema (ayah range, not ayah id) and the UI
   (expandable panel / sheet, not an inline block under the verse).
2. **Prayer start-time reminders** — notify at Fajr/Dhuhr/Asr/Maghrib/Isha. The
   notification plumbing already exists (`NotificationScheduler` + the Sunnah
   reminder rolling window), so this is mostly scheduling: prayer times are
   computed locally per day, so the window has to be re-armed on launch/resume
   like the Sunnah one, and re-armed on a location change. Decide per-prayer
   opt-in vs all-or-nothing, and whether to offer a pre-prayer lead time. Watch
   the OEM battery-killer problem already documented for reminders (OnePlus).
3. **More Sunnah occasions** — new Hijri month start, and the rest of the
   recurring calendar (Ayyam al-Beed already ships; candidates: the sacred
   months, Rajab/Sha'ban markers, Laylat al-Qadr odd nights). Extends
   `sunnah_events` + the occurrence engine; each new occasion needs a Hijri-date
   rule and a decision on whether it's informational or routes into the app.
   Anchor-table accuracy (see `quality-backlog.md` §14c) matters more once
   month-START events exist — those fire exactly on the boundary the anchors fix.
4. **More authentic translations, + Roman Urdu** — tracked centrally in
   `../alquran-data/TRANSLATIONS-ROADMAP.md`; the edition model + downloadable
   catalogue already support this, so new editions are a data-side job. Roman
   Urdu has its own repo (`../alquran-roman-urdu`) with a style guide and
   validation pipeline — that is the source, not a transliteration done here.
5. **More reciters** — Maher al-Muaiqly, Saad al-Ghamdi, Sudais and others. The
   audio layer is already namespaced per reciter (`recitation/{reciter}_{bitrate}/`
   in both the R2 path and the on-disk cache), so no collision risk; the work is
   ingesting each reciter to R2 verse-by-verse against the same global 1..6236
   index, plus a reciter picker in reader settings (`reciterId` already persists).
   Licensing per reciter needs clearing exactly as for translations.
6. **An authentic Urdu reciter** — as #5, but specifically an Urdu-language
   recitation/translation audio for the core audience. Confirm what is wanted:
   Arabic recitation by a Pakistani/Indian qari, or Urdu *translation* audio
   played after each verse — they are different products and different data.
7. **Tajweed colours** — colour-coded pronunciation rules over the Arabic. Needs
   a tajweed-annotated source (QUL exports tajweed-rule Uthmani) and a rendering
   approach: the current KFGQPC text is a single styled run, so per-rule colour
   means parsing the annotation into spans — and it must not fight the IndoPak
   script option or pinch-zoom. Verify against a printed tajweed Mushaf before
   shipping; wrong colours are a correctness problem, not a cosmetic one.

**Not sized or scheduled** — this is a capture of intent, not a commitment. When
one is picked up, check the licensing gate first (translations, reciters and
tafsir editions all carry it) and give it a `FeatureFlags` entry so it can ship
dark.

## Reference

- Translation *editions* (which languages/editions, licensing, ingestion status) are tracked centrally in `../alquran-data/TRANSLATIONS-ROADMAP.md` — don't duplicate that list here.
- Web-specific product backlog (mobile responsiveness, conversion measurement, Juz/page library browsing) lives in `../al-quran-web/docs/product-backlog.md`.
- Reader/audio bug-level backlog lives in `quality-backlog.md` in this same folder.
