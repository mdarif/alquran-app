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
# 0. on main, clean tree, everything green
make ci

# 1. (Android) cut the release through CD
make release-dry BUMP=current      # rehearse: signs + builds, releases nothing
make release     BUMP=current      # FIRST release → tag v1.0.0, signed APK+AAB, GitHub Release
#   …later releases: BUMP=patch | minor | major

# 2. (iOS) build + upload manually (no CD yet)
flutter build ipa --release        # then upload the .ipa via Transporter / Xcode Organizer

# 3. submit in the consoles (Play internal→production, App Store TestFlight→review)
# 4. verify (below), then celebrate ☕
```

First time only: add the signing secrets once — see
[docs/release.md → One-time setup](release.md#one-time-setup).

---

## 1. Preflight — before you cut anything

### A. Code is ready (mostly automated — just confirm)
- [ ] On `main`, working tree clean, pulled latest.
- [ ] `make ci` green (format + analyze + 283 tests). CI on `main` is green too.
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
   Runs the whole pipeline — codegen, format, analyze, test, **and the signed
   APK + AAB build** — but tags/releases/uploads nothing. Confirms the signing
   secrets decode and the release build is healthy.
2. **Cut it:**
   ```bash
   make release BUMP=current      # or patch/minor/major
   ```
3. Watch it: `make ci-logs` (failed-step logs of the latest run) or the Actions
   tab. On success you get:
   - the version bumped + committed to `main` (skipped for `current`),
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

### Play Console (Android)
1. App bundle is on the **internal** track (auto-uploaded, or upload the `.aab`
   manually).
2. Add testers / verify the internal release installs.
3. Complete the store listing, data-safety form, content rating, and the
   exact-alarm declaration if you chose to file it.
4. Promote **internal → production** when ready — this stays a deliberate manual
   step (human gate). Roll out staged (e.g. 20% → 100%) if you like.

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
  one. Fix forward: `make release BUMP=patch`, then promote. On Play you can also
  **halt the rollout** of a staged release.
- **Bad tag/Release on GitHub?** `git push --delete origin vX.Y.Z` + delete the
  Release in the UI, fix, re-cut. (Don't reuse a build number already accepted by
  a store.)

---

## 8. First-release checklist (v1.0.0) — do these once

- [ ] Signing secrets added — [docs/release.md → One-time setup](release.md#one-time-setup).
- [ ] (Optional) `GOOGLE_PLAY_SERVICE_ACCOUNT` added to automate Play upload;
      skip it and upload the `.aab` by hand the first time if Play isn't set up.
- [ ] Play Console: create the app `com.almarfa.alquran`, first manual internal
      upload (a service account can't create the very first release).
- [ ] App Store Connect: create the app record `com.almarfa.alquran`.
- [ ] All Section 1B/1C legal + store gates cleared.
- [ ] `make release BUMP=current` → ship v1.0.0. 🎉
