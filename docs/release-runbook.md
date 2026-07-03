# Release runbook — shipping Al Quran 🌙

The human playbook for taking Al Quran from "looks good on my phone" to "live in
the stores." For the CI/CD mechanics it leans on — secrets, the workflow, the
`make` targets — see **[docs/release.md](release.md)**. This doc is the
*sequence you follow*; that doc is *how the machine works*.

> **Identity at a glance**
> · App name: **Al Quran** · published id **`com.almarfa.alquran`** on both
> stores. (Internally, the Android Kotlin `namespace` stays `com.almarfa.al_quran`
> and the iOS App Group stays `group.com.almarfa.alQuran` — both invisible to
> users and intentionally left as-is.)
> · Version lives in `pubspec.yaml` as `X.Y.Z+BUILD` (today: `1.0.0+1`).

---

## TL;DR — the happy path

```bash
# 0. on develop, clean tree, everything green
make ci

# 1. (Android) cut the release through CD (promote → release → sync back)
make release-dry  BUMP=current     # rehearse: signs + builds develop's code, releases nothing
make release-auto BUMP=current     # FIRST release → promotes develop→main, tag v1.0.0, signed APK+AAB, GitHub Release
#   …later releases: BUMP=patch | minor | major

# 2. (iOS) build + upload manually (no CD yet)
flutter build ipa --release        # then upload the .ipa via Transporter / Xcode Organizer

# 3. submit in the consoles (Play → Production, staged ~20%; App Store TestFlight→review)
# 4. verify (below), then celebrate ☕
```

First time only: add the signing secrets once — see
[docs/release.md → One-time setup](release.md#one-time-setup).

---

## 1. Preflight — before you cut anything

### A. Code is ready (mostly automated — just confirm)
- [ ] On `develop`, working tree clean, pulled latest. (`main` is release-only —
      the workflow promotes develop→main for you.)
- [ ] `make ci` green (format + analyze + tests). CI on `develop` is green too.
- [ ] `make version` shows the version you intend to ship.
- [ ] **On-device smoke test** (the real gate): install a release build on a
      physical phone — reader scrolls smoothly, Arabic + translations render,
      pinch-zoom works, audio plays, prayer times + reminders fire. Test on the
      OnePlus (OEM battery-killer is the known reminders risk) and an iPhone.
- [ ] If you replaced `assets/db/quran.db` since the last release, you ran
      `make seed-version` (else devices won't pick up the new data).
- [ ] You did **not** regenerate `android/`/`ios/` (a `flutter create`) without
      re-running `make location-perms notif-perms audio-perms` — a regen wipes
      the permission/Info.plist edits and the home-widget native code.

### B. Legal / licensing gates (owner-side — clear before store submission)
These are **not** enforced by CI. Tick each before going public:
- [ ] **KFGQPC** — redistribution of the Arabic text + 604-page layout + the
      anchor-patched font (`tool/patch_arabic_font.py`) in a free app is cleared.
- [ ] **English (Hilali & Khan)** — King Fahd / QUL #301 terms cover store
      distribution + the attribution format we show.
- [ ] **Urdu (Junagarhi) / Hindi (Suhel Farooq Khan & Nadwi, Tanzil)** —
      redistribution cleared (Tanzil credit + link is shown in About).
- [ ] **Audio (Mishary Rashid Alafasy via islamic.network)** — terms permit
      streaming + on-device caching; attribution shown.
- [ ] **IndoPak text (Quran.com) + QUL metadata** — freely redistributable.
- [ ] **Fonts** — Noto* + Playfair (OFL) and Noorehuda (CC BY-NC) notices appear
      on the About / licenses screen.
- [ ] **Privacy policy URL** is live and covers: location (prayer times, on-device
      only), local notifications, audio streaming + caching, **no analytics /
      tracking**. Required by both stores. The policy is drafted at
      [docs/privacy-policy.md](privacy-policy.md) — add a support email and host
      it (almarfa.co or the rendered GitHub URL), then paste the URL in both
      consoles.

### C. Store-config gates
- [ ] **Play account can publish to production** — confirmed: this personal
      account already has Sharah Kitab at-Tawheed live in production, so it's
      exempt from Play's new-personal-account closed-testing gate (~12–20
      testers / 14 days). Al Quran goes straight to production. (A fresh
      personal account would need the closed test first.)
- [ ] **Android `SCHEDULE_EXACT_ALARM`** — either file the Play Console
      declaration, or accept the scheduler's inexact fallback. Decide and record.
- [ ] **Store assets** ready: icon, screenshots (phone + tablet), feature
      graphic, listing copy ("offline reading + optional audio recitation"),
      content rating questionnaire (expect Everyone / 4+). Ready-to-paste copy,
      the screenshot shot-list, and the console checklists live in
      [docs/play-store-listing.md](play-store-listing.md); store name, tagline,
      colours, and naming are in [docs/brand.md](brand.md).
- [ ] **Data-safety (Play) / privacy-nutrition (App Store)** forms filled —
      **no data collected, no tracking** (prayer-time location is processed
      on-device only and never transmitted, which under Play's definition is
      not "collection"; reasoning in
      [docs/play-store-listing.md §4](play-store-listing.md)).

> Reframe reminder: the app is **"offline reading + optional audio recitation,"**
> not "fully offline" (audio streams). Keep store copy consistent.

---

## 2. Versioning — which BUMP?

`pubspec.yaml` carries `X.Y.Z+BUILD`. The build number (`+BUILD` =
Android `versionCode` / iOS build) must **strictly increase on every store
upload** — both consoles reject a build number they've seen.

| BUMP | Use it for | `1.0.0+1` becomes | Tag |
|---|---|---|---|
| `current` | the **first** release — ship pubspec as-is | `1.0.0+1` (unchanged) | `v1.0.0` |
| `patch` | bug-fix release | `1.0.1+2` | `v1.0.1` |
| `minor` | new feature | `1.1.0+2` | `v1.1.0` |
| `major` | breaking change | `2.0.0+2` | `v2.0.0` |

Use `current` **once**, for v1.0.0. After that always pick patch/minor/major so
the build number climbs.

---

## 3. Cut the Android release (automated, via CD)

This is the one-click path. Full detail in
[docs/release.md](release.md#cutting-a-release).

1. **Rehearse** (recommended before the first real cut):
   ```bash
   make release-dry BUMP=current
   ```
   Runs the whole pipeline against `develop`'s code — codegen, format, analyze,
   test, **and the signed APK + AAB build** — but promotes/tags/releases/uploads
   nothing. Confirms the signing secrets decode and the release build is healthy.
2. **Cut it** (from `develop`):
   ```bash
   make release-auto BUMP=current      # or patch/minor/major
   ```
   The run is three jobs: **promote** (fast-forward develop→main) →
   **release** (gate, build, tag, GitHub Release, Play) → **sync-develop**
   (fast-forward the bump commit back into develop). Escape hatch if you ever
   need to re-ship exactly what's on `main`: `make release BUMP=…` from main.
3. Watch it: `make ci-logs` (failed-step logs of the latest run) or the Actions
   tab. On success you get:
   - the version bumped + committed to `main` **and synced back to `develop`**
     (both skipped for `current`),
   - tag `vX.Y.Z` pushed,
   - a **GitHub Release** with the signed `.apk`, `.aab`, and Play "What's new"
     text attached,
   - the `.aab` pushed to the **Play internal track** *iff*
     `GOOGLE_PLAY_SERVICE_ACCOUNT` is set (otherwise skipped — grab the `.aab`
     from the GitHub Release and upload by hand).

---

## 4. Cut the iOS release (manual — no CD yet)

iOS isn't in the pipeline (no Apple credentials wired up). Do it by hand:

```bash
make ipa            # = flutter build ipa --release --no-tree-shake-icons
# → build/ios/ipa/*.ipa
```

> `--no-tree-shake-icons` is required on every release build (it's baked into the
> `make apk`/`aab`/`ipa` targets and the release workflow) — we bundle a correct
> Material Symbols subset that Flutter's icon tree-shaking would otherwise corrupt.
> See [docs/brand.md](brand.md).

Then upload the `.ipa`:
- **Transporter** app (App Store → Transporter, simplest), **or**
- **Xcode → Organizer → Distribute App**, **or** `xcrun altool` / `notarytool`.

Notes:
- Signing uses your Apple Developer account / provisioning for
  `com.almarfa.alquran`. First time: create the App ID + app record in App Store
  Connect.
- Keep the iOS build number in step with `pubspec.yaml` (`flutter build ipa`
  reads it). Each upload needs a higher build number.
- Impeller stays **off** (Arabic GPOS marks) — already configured; don't flip it.

> Future enhancement: a `release-ios` lane (fastlane + App Store Connect API key)
> to fold iOS into the CD. Not done for v1.

---

## 5. Submit in the consoles

### Play Console (Android) — first release, straight to production (staged)

> **Account gate — cleared.** Play's "closed test with ~12–20 testers for 14
> days before production" rule applies to *new personal accounts*. This account
> (Al Marfa Technologies, personal) already has **Sharah Kitab at-Tawheed live
> in production**, so it's exempt — Al Quran can publish straight to production.
> A brand-new personal account would have to run a closed test first; this one
> doesn't. (Kept here for future reference.)

1. **Create the app** — Play Console → *Create app* → `com.almarfa.alquran`,
   Free. (Al Quran isn't on Play yet; only Tawheed is.) A service account can't
   create the first release, so this and the first upload are manual.
2. **Complete the listing + declarations** — store listing (copy/assets from
   [docs/play-store-listing.md](play-store-listing.md)), privacy-policy URL,
   **Data safety = no data collected / no tracking**, content rating (expect
   Everyone), and the `SCHEDULE_EXACT_ALARM` declaration (or accept the inexact
   fallback). Tawheed's existing listing is a working precedent for each form.
3. **Upload the AAB** — grab the signed `.aab` from the GitHub Release the CD
   just created (the pipeline skips the Play upload until
   `GOOGLE_PLAY_SERVICE_ACCOUNT` is set). Put it on the **Production** track.
4. **Staged rollout** — start the production rollout **sub-100% (e.g. 20%)** and
   submit for review. Once live, watch the **crash-free rate + reviews** in
   *Play Console → Android vitals* for a couple of days, then ramp 20 → 50 →
   100%. **Halt the rollout** at the first crash spike or text-fidelity report.
   (Staged rollout mostly protects *existing* users on *updates*; on a first
   release from ~0 users it just throttles new installs while you watch vitals —
   so the crash-free rate matters more than the percentage.)

### App Store Connect (iOS)
1. The build appears under **TestFlight** after processing (minutes).
2. Smoke-test via TestFlight.
3. Fill the app listing + privacy nutrition labels, attach the build, submit for
   **review**.
4. After approval, release (manually or auto).

---

## 6. After shipping — verify

- [ ] GitHub Release exists for `vX.Y.Z` with `.apk` + `.aab` attached.
- [ ] `git tag` is on `main`; `pubspec.yaml` version matches (for bumped releases).
- [ ] `develop` is in sync: `git fetch && git log origin/develop..origin/main`
      prints nothing (the sync-develop job fast-forwarded the bump commit back).
- [ ] Install the **store build** (internal track / TestFlight) on a real device
      and re-run the smoke test — fonts, translations, audio, prayer times,
      reminders.
- [ ] Listing reads correctly; privacy policy link works.
- [ ] No crash-reporting SDK by design — watch user feedback channels instead.

---

## 7. If a release goes bad (rollback / hotfix)

- **Not yet promoted to production?** Easiest — halt the internal/TestFlight
  release; nothing public shipped.
- **Already in production?** You can't un-publish a build, only ship a higher
  one. Fix forward: land the fix on `develop`, then `make release-auto
  BUMP=patch` and promote in the console. On Play you can also **halt the
  rollout** of a staged release.
- **Bad tag/Release on GitHub?** `git push --delete origin vX.Y.Z` + delete the
  Release in the UI, fix, re-cut. (Don't reuse a build number already accepted by
  a store.)

### Branch-flow troubleshooting

- **promote failed: "Refusing to promote… confirm_promote"** — dispatched from
  develop without the flag. `make release-auto` sets it; in the Actions UI tick
  the `confirm_promote` checkbox. Nothing was pushed.
- **promote failed: "not possible to fast-forward"** — `main` has a commit that
  develop lacks (an escape-hatch release, or someone pushed to main by hand).
  Recover on develop: `git fetch && git merge origin/main` — if `pubspec.yaml`
  conflicts, keep the **higher** version — push develop, re-run the release.
- **sync-develop failed: "not possible to fast-forward"** — develop picked up
  its own commits while the release was building. **The release itself already
  shipped — do not re-run the workflow** (the versionCode is consumed on Play).
  Recover on develop: `git fetch && git merge origin/main`, resolve
  `pubspec.yaml` keeping the **higher** version, push. Done — no new release
  needed.
- **release failed after the Play upload but before the tag/Release** (rare —
  the upload step runs first): the internal track already holds that
  versionCode. Don't re-run with the same version; finish by hand — tag the
  built SHA (`git tag vX.Y.Z <sha> && git push origin vX.Y.Z`) and
  `gh release create` with the artifacts, or cut a fresh `BUMP=patch`.
- **"src refspec main does not match any"** — shouldn't recur (the workflow
  pushes `HEAD:main` precisely because the release job runs on a detached-HEAD
  SHA checkout); if it appears, someone edited the push refspec.

---

## 8. First-release checklist (v1.0.0) — do these once

- [x] Signing secrets added — [docs/release.md → One-time setup](release.md#one-time-setup).
      (Done 2026-07-03; dry run from develop went green through the signed build.)
- [ ] (Optional) `GOOGLE_PLAY_SERVICE_ACCOUNT` added to automate Play upload;
      skip it and upload the `.aab` by hand the first time (that's the plan for v1).
- [ ] Play account exempt from the closed-testing gate — confirmed (Tawheed is
      live in production on the same personal account).
- [ ] Play Console: **create the app** `com.almarfa.alquran`, then the first
      manual upload straight to **Production** (a service account can't create
      the very first release).
- [ ] App Store Connect: create the app record `com.almarfa.alquran` (iOS later).
- [ ] All Section 1B/1C legal + store gates cleared (licensing, privacy-policy
      URL hosted, Data safety, content rating, exact-alarm).
- [ ] From `develop`: `make release-auto BUMP=current` → v1.0.0 tag + GitHub
      Release with the signed AAB → upload to **Production at ~20%** → ramp. 🎉
