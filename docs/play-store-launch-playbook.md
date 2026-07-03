# Play Store launch playbook (reusable across Al-Marfa apps)

The end-to-end "from `Create app` to **live in production**" sequence for a
Google Play launch, written so it works for the **next** app too — Al Quran is
the worked example, per-app values are called out so you can swap them. Pairs
with: [play-store-listing.md](play-store-listing.md) (the actual listing copy +
screenshots), [play-store-service-account-setup.md](play-store-service-account-setup.md)
(CI auto-upload), and [release-runbook.md](release-runbook.md) (cutting the build).

> **Golden rule:** a service account **cannot create the app or its first
> release** — the first upload is always manual. Wire up CI auto-upload *after*
> v1.0.0 is live (it takes over from v1.0.1).

## Per-app values (fill these for each new app)

| Thing | Al Quran |
|---|---|
| Play package (`applicationId`) | `com.almarfa.alquran` |
| App name (≤30) | `Al Quran — Read Offline` |
| Category | Books & Reference |
| Default listing language | English (US) |
| Free/paid | **Free** (one-way; required — non-commercial content licenses) |
| Contains ads | No |
| Uses Advertising ID (AD_ID) | No |
| Collects/transmits user data off-device | No (see Data safety below) |
| Requests location | Yes — on-device only (prayer times) |
| Exact alarms (`SCHEDULE_EXACT_ALARM`) | Yes (Sunnah reminders) — declare or accept inexact |
| Privacy policy URL | <https://kitabattawheed.com/privacy/> (live; shared w/ Tawheed) · support email hello@almarfa.co |

---

## Phase 0 — before Play Console (one-time per app / per account)

- [ ] Google Play developer account exists (personal account already has Tawheed
      live → **exempt from the new-account 20-tester/14-day closed-test gate**; a
      brand-new account is **not** — it must run closed testing before production).
- [ ] Release signing wired in CI (upload keystore + the 4 signing secrets) —
      [release.md → One-time setup](release.md#one-time-setup).
- [ ] A signed `.aab` exists to upload (from the CD's GitHub Release, or
      `make aab` locally).
- [x] Privacy policy hosted at a public URL + a support email chosen —
      <https://kitabattawheed.com/privacy/> · hello@almarfa.co.

## Phase 1 — Create app

Play Console → **Create app**:
- [ ] App name, default language, **App**, **Free**.
- [ ] Declarations: Developer Programme Policies ✅, Play app signing ToS ✅,
      US export laws ✅ (standard HTTPS only → export-exempt).
- Package name is **not** asked here — it binds when you upload the first AAB.

## Phase 2 — "Set up your app" → App content declarations

Left nav → **Policy → App content** (the dashboard lists these as tasks). Do all
of them — Play blocks production until every one is green:

- [ ] **Privacy policy** — paste the hosted URL.
- [ ] **App access** — "All functionality is available without special access"
      (no login/gated features in Al Quran).
- [ ] **Ads** — **No**, the app has no ads.
- [ ] **Content ratings** — start the IARC questionnaire, enter the support
      email, category *Reference / Educational*, answer **No** to all
      violence/sexual/profanity/controlled-substance/gambling questions → expect
      **Everyone / PEGI 3**.
- [ ] **Target audience and content** — select **13+** age bands (13–15, 16–17,
      18+). *Avoid ticking under-13* for v1: it pulls the app into the
      **Designed for Families** programme (extra policy + privacy affirmations).
      The content is child-safe, so add younger bands later if you want — but
      it's avoidable complexity at launch.
- [ ] **Data safety** — see the dedicated walkthrough below.
- [ ] **Advertising ID** — declare the app does **not** use it. ⚠️ First
      confirm no dependency dragged in the `AD_ID` permission: check the merged
      manifest (`build/app/outputs/…/AndroidManifest.xml` or
      `flutter build appbundle` output) for
      `com.google.android.gms.permission.AD_ID`. If present but unused, add a
      `<uses-permission … tools:node="remove"/>` for it; then declare "No".
- [ ] **News app** — No. **Government app** — No. **Financial features** — None.
      **Health** — No/None. (All the "is your app a special category" toggles →
      the safe answer for a Qur'an reader is No/None.)

### Data safety form — the fiddly one

Play Console → App content → **Data safety** → Start. Al Quran's answer is
**"No data collected or shared"**, but the reasoning matters if review asks:

- **"Does your app collect or share any of the required user data types?"** →
  **No**. Justification kept on file:
  - **Location** is used only to compute prayer times **on the device** and is
    **never transmitted off it** — under Play's definition ("collection =
    transmitting data off the device") that is *not* collection.
  - **Audio** streams from `islamic.network`; the device fetching a verse file
    exposes an IP to the CDN as ordinary network connectivity (Play exempts
    this), and no personal data or identifiers are sent.
  - **No** analytics, ads, accounts, or crash-reporting SDKs.
- Because collection = No, the data-type matrix, "data shared," and deletion
  sections are skipped. (Security: the audio fetch is HTTPS = encrypted in
  transit.)
- **Conservative alternative** (also passes): declare **Location →** collected,
  purpose *App functionality*, **not shared**, processed on-device. Pick "No" for
  the cleanest label; either is defensible.

## Phase 3 — Store settings + Main store listing

- [ ] **Store settings** → app **category** (Books & Reference), tags, and
      **contact details** (support email required; website/phone optional).
- [ ] **Main store listing** → app name, short description (≤80), full
      description (≤4000), app icon **512×512**, **feature graphic 1024×500**,
      and **≥2 phone screenshots** (we have an 8-shot list). All copy + the
      shot-list + the feature-graphic spec are in
      [play-store-listing.md](play-store-listing.md).

## Phase 4 — Production release (staged)

Play Console → **Production → Create new release**:
- [ ] Play App Signing: accept/continue (Play holds the app-signing key; your
      keystore is the *upload* key).
- [ ] **Upload the signed `.aab`** (from the CD's GitHub Release for v1.0.0).
- [ ] Release name + "What's new" notes (from [play-store-listing.md §6](play-store-listing.md)).
- [ ] **Rollout percentage: start ~20%.** Review → Start rollout to Production.
- [ ] Google review (hours→days for a new app). Once live, watch **Android
      vitals** (crash-free rate) + reviews, then ramp 20 → 50 → 100%. **Halt** on
      a crash spike or text-fidelity report. (Staged rollout mainly protects
      existing users on *updates*; on a first release the crash-free rate matters
      more than the %.)

## Phase 5 — Automate future uploads (do after v1.0.0 is live)

- [ ] Set up the Play service account so **v1.0.1+ auto-uploads** to the internal
      track — full procedure (reuse Tawheed's SA, or dedicated) in
      [play-store-service-account-setup.md](play-store-service-account-setup.md).
      Then each `make release-auto BUMP=…` lands the AAB on Play automatically;
      you just promote internal → production (staged) in the console.

## Phase 6 — Post-launch verify

- [ ] Install the **store build** on a real device; smoke-test fonts,
      translations, audio, prayer times, reminders (OnePlus = OEM reminder-killer
      risk).
- [ ] Store listing reads correctly; privacy-policy link resolves.
- [ ] Crash-free rate healthy through the 20% stage before ramping.

---

## For the next app — what changes vs. what's copy-paste

- **Changes per app:** the Per-app values table, listing copy/assets, the
  content-rating answers if the app has different content, and whether it needs
  location/exact-alarm/audio declarations.
- **Copy-paste:** this whole phase order; the App-content answers for a
  no-ads/no-tracking utility; the signing + service-account CI setup (a new SA,
  or reuse the shared one); the staged-rollout discipline.
- **Account gate reminder:** if the next app goes on a **brand-new** developer
  account, you must run **closed testing (≥ the current tester minimum, 14 days)
  before production** — budget for it. On this established account, straight to
  production is fine.
