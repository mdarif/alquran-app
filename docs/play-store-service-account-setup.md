# Google Play service account — create & add the key (Al Quran)

How to give CI permission to upload the Al Quran `.aab` to Google Play
automatically. This is the setup behind the **`GOOGLE_PLAY_SERVICE_ACCOUNT`**
secret that [../.github/workflows/flutter-release.yml](../.github/workflows/flutter-release.yml)
reads to run its `r0adkll/upload-google-play` step. Until this is done, releases
still succeed — the workflow just **skips** the Play upload and attaches the
signed `.aab` to the GitHub Release instead (see the "Check Play Store
availability" gate in the workflow).

**App facts this guide is wired to** (don't guess these — they're the real values):

| Thing | Value |
|---|---|
| Play package name (`applicationId`) | `com.almarfa.alquran` |
| Android `namespace` (internal, ≠ applicationId — do **not** align them) | `com.almarfa.al_quran` |
| GitHub repo | `mdarif/alquran-app` |
| CI secret name | `GOOGLE_PLAY_SERVICE_ACCOUNT` |
| Upload track (CI) | `internal` |
| Play developer account | the personal Al Marfa account (already has *Sharah Kitab at-Tawheed* live) |

---

## TL;DR — two paths, pick one

Because **Al Quran and Al‑Tawheed live under the same Play developer account**,
you have a choice:

- **Path A — Reuse the existing Tawheed service account (recommended, ~5 min).**
  One Google Cloud service account can be granted access to *many* apps in the
  same Play Console. You **skip all of the GCP steps** (no new project, no new
  key) and only do: (1) grant the existing account app‑level access to Al Quran
  in Play Console, (2) set the same JSON as this repo's secret. Jump to
  [Path A](#path-a--reuse-the-tawheed-service-account-recommended).

- **Path B — A fresh, dedicated service account for Al Quran (full walkthrough).**
  Cleaner blast‑radius isolation (revoking Al Quran's key never touches Tawheed),
  at the cost of a second key to manage. This is the full
  console.cloud.google.com procedure. Jump to
  [Path B](#path-b--create-a-dedicated-service-account-full-gcp-walkthrough).

Either way, **the app must already exist in Play Console with one manual upload
done first** — a service account *cannot create the app or the first release*.
See [Prerequisite](#prerequisite-the-app--first-release-must-exist).

---

## Prerequisite: the app + first release must exist

A service account can automate uploads to an **existing** track of an
**existing** app. It cannot bootstrap either. So before wiring CI:

1. **Create the app** — Play Console → **Create app** → name it, package
   `com.almarfa.alquran`, app/game = App, Free. (Al Quran isn't on Play yet.)
2. **Do one manual release** — build the signed `.aab` locally (`make release`
   or the CI dry‑run artifact) and upload it **by hand** once, to the track CI
   will use (**Internal testing** → or straight to **Production**, since this
   account is exempt from the new‑account 14‑day/20‑tester rule — see
   [release-runbook.md](release-runbook.md)). This also unlocks the Play API for
   that track. If you skip it, the first automated upload fails with a
   *"no application was found for the given package name"* / track‑not‑found
   error.
3. Complete the one‑time store forms (Data safety = **no data collected / no
   tracking**, content rating, target audience, privacy policy). Unrelated to
   the service account, but Play won't let you publish without them.

---

## Path A — reuse the Tawheed service account (recommended)

The existing account is:

```
github-actions-play@al-tawheed-play.iam.gserviceaccount.com
```

and its JSON key is saved at:

```
/Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed/Service Account JSON/
```

### A1. Grant it access to Al Quran (Play Console — this is the step people miss)

Play Console → **Users and permissions** → find
`github-actions-play@al-tawheed-play.iam.gserviceaccount.com` → **Manage** →
under **App permissions** click **Add app** → select **Al Quran** → grant:

- **Release** to testing tracks, **and**
- ✅ **Manage testing tracks and edit tester lists** *(a.k.a. "Manage testing
  tracks")*.

> **⚠️ The 403 trap (learned the hard way on Tawheed).** Account‑level *"Release
> apps to testing tracks"* alone is **not enough** — the upload 403s. The
> permission that actually matters must be granted at the **app level** for Al
> Quran, and it must include **Manage testing tracks**. If CI 403s on upload,
> this is almost always why.

No GCP work is needed — the account, project, and key already exist.

### A2. Point this repo's secret at the existing JSON

Run in your **terminal** (never paste JSON into chat or commit it):

```sh
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT \
  --repo mdarif/alquran-app \
  < "/Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed/Service Account JSON/<file>.json"
```

Done — skip to [Verify](#verify-it-works).

---

## Path B — create a dedicated service account (full GCP walkthrough)

This is the complete **console.cloud.google.com** procedure, mirroring how the
Tawheed account was created but isolated to Al Quran.

### B1. Project — [console.cloud.google.com](https://console.cloud.google.com)

- Top project dropdown → **New Project**.
- Name: `al-quran-play` (any name; this is the suggested convention) → **Create**.
- Make sure the new project is **selected** in the top bar before continuing.

### B2. Enable the Play Developer API

- **APIs & Services → Library** → search **"Google Play Android Developer API"**
  → **Enable** (for the `al-quran-play` project).

### B3. Create the service account

- **IAM & Admin → Service Accounts → + Create service account**.
- Name: `github-actions-play` → this generates the email
  **`github-actions-play@al-quran-play.iam.gserviceaccount.com`**.
- **Grant this service account access to project**: leave **empty** — Play
  permissions are granted on the Play Console side, not via GCP IAM roles.
- **Done**.

### B4. Create the JSON key  ← *the "create key" step*

- Click the new service account → **Keys** tab.
- **Add Key → Create new key → JSON → Create**.
- The `.json` downloads automatically. Move it somewhere private and **out of
  the repo** — e.g.:

  ```
  /Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Quran/Service Account JSON/
  ```

  > This file is a **credential**. Never commit it, never paste it in chat. It's
  > already covered by `.gitignore` patterns for `*.json` keys, but keep it in
  > Dropbox, not the repo tree.

### B5. Link the project in Play Console

- Play Console → **Setup → API access**.
- **Link** the `al-quran-play` Google Cloud project (or, if it offers to, accept
  the existing linkage). After linking, the `github-actions-play@al-quran-play…`
  service account appears in the list.

### B6. Grant app‑level permissions (same 403 trap as Path A)

- Play Console → **Users and permissions** → the
  `github-actions-play@al-quran-play.iam.gserviceaccount.com` account →
  **Manage** → **App permissions → Add app → Al Quran** → grant **Release** +
  ✅ **Manage testing tracks**. App‑level, not account‑level only.

### B7. Set the GitHub secret

```sh
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT \
  --repo mdarif/alquran-app \
  < "/Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Quran/Service Account JSON/<file>.json"
```

---

## Verify it works

1. **Secret is set:**

   ```sh
   gh secret list --repo mdarif/alquran-app | grep GOOGLE_PLAY_SERVICE_ACCOUNT
   ```

2. **Dry‑run the release workflow** (won't upload, but the "Check Play Store
   availability" gate will report `enabled=true` once the secret exists):

   ```sh
   gh workflow run flutter-release.yml --repo mdarif/alquran-app -f dry_run=true
   gh run watch --repo mdarif/alquran-app
   ```

   Look for: *"Play Store service account present — will upload the AAB to the
   internal track."*

3. **Real run:** the **Upload to Play Store (internal track)** step should push
   `build/app/outputs/bundle/release/app-release.aab` to the **internal** track
   with `whatsnew-en-US`. Confirm the build appears in Play Console → **Testing →
   Internal testing**.

---

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| Upload step **403 / "does not have permission"** | The account has account‑level release but **not app‑level "Manage testing tracks"** for Al Quran. Fix in Play Console → Users and permissions → the SA → App permissions → Al Quran (Path A step A1 / Path B step B6). |
| **"No application was found for the given package name `com.almarfa.alquran`"** | The app doesn't exist yet, **or** no manual upload has ever been made to that track. Do the [Prerequisite](#prerequisite-the-app--first-release-must-exist) first. |
| Upload step **skipped**, `.aab` only on GitHub Release | `GOOGLE_PLAY_SERVICE_ACCOUNT` isn't set. Run the `gh secret set …` command. This is a *graceful skip by design*, not a failure. |
| **"APIs not enabled"** | Path B only — enable **Google Play Android Developer API** for the project (B2). |
| Wrong track / went to production unexpectedly | CI uploads to `track: internal` (see the `r0adkll/upload-google-play` step). Promotion to Production is a **manual** gate in Play Console. |
| Package‑name mismatch (`al_quran` vs `alquran`) | Play uses **`com.almarfa.alquran`** (the `applicationId`). The `namespace` `com.almarfa.al_quran` is internal‑only; they intentionally differ — do not "align" them. |

---

## Security & lifecycle notes

- **The JSON key does not expire on its own.** But if you ever **rotate or
  delete** it (GCP → Service Account → Keys tab), you must re‑run
  `gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT …` with the new file, or CI uploads
  break.
- **Least privilege:** grant only *Release + Manage testing tracks*. Do not give
  the service account Admin/Owner.
- **Never** commit the JSON or paste its contents anywhere. Set the secret from
  the file with `gh secret set … < file`, which streams it without echoing.
- **Path A vs B trade‑off:** reusing one account is fewer moving parts; a
  dedicated account means revoking Al Quran's key can never affect Tawheed. For a
  two‑app solo setup, Path A is usually the right call.

---

### See also

- [release-runbook.md](release-runbook.md) — the full release procedure (this
  secret is one input to it).
- [release.md](release.md) — how the release workflow is wired end‑to‑end.
- [.github/workflows/flutter-release.yml](../.github/workflows/flutter-release.yml)
  — the `Check Play Store availability` gate and the `Upload to Play Store` step.
