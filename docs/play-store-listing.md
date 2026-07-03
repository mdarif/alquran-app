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
A beautiful offline Qur'an — Uthmani & IndoPak, Urdu, Hindi & English. No ads.
```
(78 chars.)

### Full description (max 4000 chars)

```
Al Quran is a Qur'an reader built for one thing: long, comfortable, distraction-free reading. No ads. No accounts. No tracking — ever.

READ, BEAUTIFULLY
• The complete Qur'an in the authentic KFGQPC Uthmani (Madani) script
• IndoPak (South-Asian) script option, rendered in the Noorehuda typeface
• Reading mode: pure Arabic, nothing else on the page
• Detailed mode: every verse with Urdu, Hindi and English translations
• Pinch-to-zoom and font-size controls for effortless legibility
• "Light of Day": the page's light adapts gently to the time of day

FULLY OFFLINE
The entire Qur'an, all translations and navigation are bundled with the app. Read anywhere — no internet needed, ever. The one optional online feature is audio recitation.

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
No ads, no analytics, no accounts. Your reading, your location and your habits never leave your device. See our privacy policy for the details.

Al Quran is built with care by Al Marfa Technologies — simple, beautiful apps that benefit Muslims. If something isn't right, we'd love to hear from you before you leave a review.
```
(~1900 chars — room to grow.)

### Category & tags

- **Category:** Books & Reference (alt: Lifestyle)
- **Tags:** Quran, Islam, Offline, Urdu, Hindi, Prayer times
- **Email:** the developer support email (Play requires one — owner TODO)
- **Website:** https://almarfa.co

---

## 2. Screenshot shot-list (phone, portrait)

Capture 6–8; Play needs 2+ phone screenshots (min 320 px, max 3840 px,
16:9–9:16). Suggested order tells the app's story:

| # | Screen | How to stage it |
|---|--------|-----------------|
| 1 | Home — reading-first, next-prayer pill, Hijri dateline | Fresh launch, daytime |
| 2 | Reader, Reading mode — pure Uthmani page | Surah Al-Fatiha or Al-Kahf opening |
| 3 | Reader, Detailed mode — Arabic + Urdu + Hindi + English | Ayat al-Kursi (2:255) |
| 4 | Script choice — IndoPak rendering | Same verse as #3 for contrast |
| 5 | Audio recitation playing (verse highlighted) | Tap a verse, capture mid-playback |
| 6 | Prayer-times sheet (all five + Hijri date) | Tap the prayer pill |
| 7 | Sunnah reminders sheet | Home → reminders button |
| 8 | Pinch-zoom / large-type reading (accessibility story) | Max font, Reading mode |

Capture commands:

```bash
# Android (device/emulator):
adb exec-out screencap -p > docs/store-assets/screenshots/01-home.png
# iOS simulator:
xcrun simctl io booted screenshot docs/store-assets/screenshots/ios-01-home.png
```

Tips (from Al-Tawheed's workflow):
- Status bar: full battery, no notification icons (emulator demo mode:
  `adb shell settings put global sysui_demo_allowed 1` then the demo-mode
  broadcasts), clock set to a tidy time.
- Keep one visual story per shot; no overlapping sheets.
- Al-Tawheed's `scripts/frame_screenshots.py` (device frame + brand gradient +
  caption) can be borrowed later for framed marketing shots; plain screenshots
  are fine for v1.
- Tablet screenshots are optional for v1 — add a 7"/10" set once the phone
  listing is live.

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
   with Sharah Kitab al-Tawheed). Support/contact email: hello@almarfa.co.
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
