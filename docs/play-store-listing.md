# Store listing — Al Quran (Play Store + App Store)

Everything to paste into the consoles for the first (v1.0.0) listing, plus the
screenshot shot-list and the declarations both stores will ask for. Structure
borrowed from Al-Tawheed's `docs/play-store-listing.md`; copy tailored to this
app's v1 (Surah-only nav, prayer times ON, audio ON — see
`lib/core/feature_flags.dart` and the v1 readiness notes).

> Companion docs: [release-runbook.md](release-runbook.md) (the ship-it
> sequence) · [release.md](release.md) (CD mechanics) ·
> [privacy-policy.md](privacy-policy.md) (host this, then paste its URL in both
> consoles).

---

## 1. Play Store copy (paste into Play Console → Store presence)

### App name (max 30 chars)

```
Al Quran — Read Offline
```
(23 chars. The launcher name stays "Al Quran"; the store name may carry the
qualifier for search.)

### Short description (max 80 chars)

```
A beautiful offline Qur'an reader — Uthmani & IndoPak, Urdu, Hindi & English.
```
(77 chars. **No price/promo keywords here** — Play flags "No ads / Free / sale" in
the *short* description and drops promotability, so keep them out. The full
description below may still say "no ads"; the rule only bites the short one.)

### Full description (max 4000 chars)

```
Al Quran is a Qur'an reader built for one thing: long, comfortable, distraction-free reading. No ads. No accounts. No tracking — ever.

READ, BEAUTIFULLY
• The complete Qur'an in the authentic KFGQPC Uthmani (Madani) script
• IndoPak (South-Asian) script option, rendered in the Noorehuda typeface
• Reading mode: pure Arabic, nothing else on the page
• Detailed mode: every verse with Urdu, Hindi and English translations
• Search — find any surah by name, number, or a verse reference (like "Muhammad 10")
• Pinch-to-zoom and font-size controls for effortless legibility
• "Light of Day": the page's light adapts gently to the time of day

OFFLINE-FIRST
The complete Qur'an, all translations, and navigation are bundled in the app — read anywhere, no internet needed. The only optional online feature is audio recitation.

TRANSLATIONS
• Urdu — Maulana Muhammad Junagarhi
• Hindi — Suhel Farooq Khan & Saifur Rahman Nadwi
• English — Dr. Hilali & Dr. Muhsin Khan

LISTEN (OPTIONAL)
Tap any verse to hear it recited by Mishary Rashid Alafasy, or let the recitation flow verse by verse to the end of the surah. Audio is streamed and cached, so replays work offline.

STAY ON TRACK
• Continue exactly where you left off with Last Read
• Accurate, fully on-device prayer times with a glanceable next-prayer pill
• Hijri date at a glance
• Gentle Sunnah reminders (Monday/Thursday fasts, Ayyam al-Bid, Friday Surah al-Kahf and more)
• Share a verse with its translation in one tap

PRIVATE BY DESIGN
No ads, no analytics, no accounts. Your reading, your location, and your habits never leave your device.

Built with care by Al Marfa Technologies — simple, beautiful apps that benefit Muslims. Questions or feedback? Email hello@almarfa.co.
```
(~1900 chars — room to grow. NOTE: no "contact us before a negative review"
wording and no unverifiable "FULLY OFFLINE" claim — both trip Play's metadata
policy; keep it this way.)

Store icon: `docs/store-assets/play-icon-512.png` (512×512, generated from
`assets/icon/icon.png`).

### Category & tags

- **Category:** Books & Reference (alt: Lifestyle)
- **Tags:** Quran, Islam, Offline, Urdu, Hindi, Prayer times
- **Email:** the developer support email (Play requires one — owner TODO)
- **Website:** https://almarfa.co

---

## 2. Screenshots (what ships)

Framed PNGs are generated, not uploaded raw. Two pipelines under
`docs/store-assets/`, both brand-framed (deep-green radial + Playfair caption):

- **`make_screenshots.py`** → `screenshots/phone/` (7 shots) + `screenshots/tablet/`
  (7-inch breadth set). Reads device captures from `screenshots/raw/`.
- **`make_tablet_shots.py`** → `screenshots/tablet-10in/` (2 actual 10-inch
  tablet shots, landscape). Reads `screenshots/raw-tablet/`.

**Phone (7) — one continuous session: Al-Baqarah, Fajr light (`#EAEEF1`), anchor
verse 2:2, reading font 32, ending on pinch-to-zoom.** Slots 1–2 kept from v1:

| # | Screen |
|---|--------|
| 1 | Home — surah list, next-prayer pill, Hijri dateline |
| 2 | Reader, Reading mode — Al-Baqarah, Uthmani |
| 3 | Tap verse 2:2 → peek card (Urdu translation + audio) |
| 4 | Detailed mode — verse 2:2 with Urdu + Hindi + English |
| 5 | Light of Day — Reading Light sheet, Fajr held |
| 6 | Settings — script, size & language |
| 7 | Pinch-zoom / large-type reading |

**10-inch tablet (2) — actual captures from a Pixel Tablet emulator
(2560×1600), landscape:** reading (wide Uthmani mushaf) + detailed (Arabic +
translation across the page), both Al-Baqarah / Fajr.

**Capture** (Android device/emulator): `adb exec-out screencap -p > …/raw/NN-name.png`
(1272×2800 phone; 2560×1600 tablet), then run the matching pipeline. Captions
live in the scripts, so re-running reframes everything. Status-bar clutter is
cropped by the framer, so demo mode isn't required.

## 3. Feature graphic (1024×500, required by Play)

Follow Al-Tawheed's `docs/store-assets/feature-graphic-spec.md` approach:
- Deep brand green `#093E26` field, the gold calligraphic **Q** mark
  (from `assets/brand/`, no Quranic text per the brand guardrail),
  wordmark "Al Quran" + tagline "Read. Reflect. Remember."
- PNG/JPG, no alpha, keep text inside the central safe area.
- Store it at `docs/store-assets/feature-graphic-1024x500.png` when produced
  (the Brand Studio in `assets/brand/` can compose it).

---

## 4. Play Console — first-submission checklist (in order)

> **Straight to production (staged).** The dev account (Al Marfa, personal)
> already has Sharah Kitab at-Tawheed live in production, so it's exempt from
> Play's new-personal-account closed-testing gate — Al Quran goes direct to the
> Production track, no closed test required. Tawheed's existing listing is a
> working precedent for every form below.

1. Create app (`com.almarfa.alquran`, App, Free) in the Play Console.
2. **Store presence → Main store listing:** copy from §1, screenshots from §2,
   feature graphic from §3, app icon 512×512 (export from
   `assets/icon/icon.png`).
3. **Privacy policy URL** — <https://kitabattawheed.com/privacy/> (live; shared
   with Sharah Kitab at-Tawheed). Support/contact email: hello@almarfa.co.
4. **App content declarations:**
   - **Data safety:** declare **no data collected, no data shared**. Rationale:
     no analytics/ads/accounts; prayer-time location is processed on-device
     only and never transmitted; the audio CDN sees an IP address as part of
     basic connectivity (documented in the privacy policy). Mark "data
     encrypted in transit" for the audio stream and "users can request
     deletion" as N/A (nothing collected).
   - **Ads:** No.
   - **Target audience & content:** Everyone; content rating questionnaire →
     reference/religious text, no user-generated content → expect
     "Everyone/PEGI 3".
   - **SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM declaration:** required — pick
     the *alarm & reminder* use case (user-scheduled Sunnah reminders fire at
     precise times). Alternative: accept the inexact fallback and drop the
     permission (owner decision, see v1 readiness notes).
   - **App access:** all functionality available without credentials.
5. **Release → Production:** upload the signed AAB (grab it from the GitHub
   Release the CD created; the pipeline skips the direct Play upload until
   `GOOGLE_PLAY_SERVICE_ACCOUNT` is set). Set the rollout to **~20%** and submit
   for review.
   - Optional sanity step first: drop the same AAB on the **Internal testing**
     track, install via the opt-in link, smoke-test on-device — then promote /
     re-upload to Production. Fast (no review) but not required.
6. **Staged ramp:** once live, watch the crash-free rate + reviews in *Android
   vitals* for a couple of days, then ramp 20 → 50 → 100%. Halt the rollout on
   any crash spike or text-fidelity report. (On a first release from ~0 users
   the % mostly throttles new installs — the crash-free rate is the real signal;
   staged rollout earns its keep on later *updates*, protecting existing users.)

## 5. App Store (iOS) copy

- **Name (30):** `Al Quran — Read Offline`
- **Subtitle (30):** `Read. Reflect. Remember.`
- **Keywords (100):** `quran,koran,offline,urdu,hindi,uthmani,indopak,hafs,tilawat,prayer times,islam,ramadan`
- **Description:** reuse §1 full description verbatim.
- **Privacy nutrition label:** **Data Not Collected** (matches the privacy
  policy; location on-device only, no identifiers, no tracking → no ATT
  prompt needed).
- **Age rating:** 4+. **Export compliance:** already answered in the app
  (`ITSAppUsesNonExemptEncryption=false` in Info.plist).
- Screenshots: 6.7" + 6.1" sets from the §2 shot-list (simulator capture).

## 6. Release notes — v1.0.0 ("What's new", ≤500 chars)

```
Assalamu alaikum! This is the first release of Al Quran:

• The complete Qur'an in authentic Uthmani script, with an IndoPak option
• Urdu, Hindi & English translations
• 100% offline reading — no ads, no accounts, no tracking
• Optional verse-by-verse recitation by Mishary Rashid Alafasy
• On-device prayer times, Hijri date & Sunnah reminders
• Pinch-to-zoom, Last Read resume, verse sharing

Read. Reflect. Remember.
```

For later versions the CD auto-generates notes from the changelog
(git-cliff → `play-store-notes.txt` on the GitHub Release); prefer rewriting
them by hand here, per-version, before pasting into the consoles.
