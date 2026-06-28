# Release runbook — Al Quran

One-click CD from the single `main` branch. Cutting a release runs the full
quality gate, builds a **production-signed** APK + AAB, generates a changelog,
tags the commit, publishes a GitHub Release with the artifacts attached, and
(optionally) uploads the AAB to the Play Store internal track.

> Looking for the full ship-it playbook (preflight checklist, iOS, store
> submission, post-release)? See **[docs/release-runbook.md](release-runbook.md)**.
> This doc is the CD *mechanics*; that one is the *sequence you follow*.

- Workflow: [.github/workflows/flutter-release.yml](../.github/workflows/flutter-release.yml)
- Trigger: `make release BUMP=<current|patch|minor|major>` (or Actions →
  **Release** → *Run workflow*).
- CI (every push/PR to `main`): [.github/workflows/flutter-ci.yml](../.github/workflows/flutter-ci.yml)
  — codegen → format → analyze → test (+ Codecov).

## One-time setup

The release workflow needs a few **repository secrets**. Set them once with the
GitHub CLI (`gh auth login` first). Signing is **required**; Play upload and
Codecov are **optional** — the pipeline skips them cleanly when their secret is
absent, so you can ship GitHub Releases today and wire up Play later.

### 1. Signing secrets (required)

Al Quran signs with the shared Al-Marfa **upload keystore** (the same key
Al-Tawheed uses; Play App Signing then gives each app its own app-signing key).
The local, git-ignored `android/key.properties` already points at it:

```
keyAlias=upload
storeFile=…/Dropbox/Al-Marfa/Al-Tawheed/Keys/upload-keystore.jks
```

Mirror those four values into secrets — `KEY_ALIAS`, `KEY_PASSWORD`,
`STORE_PASSWORD`, and the base64 of the `.jks`:

```bash
KS="$HOME/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed/Keys/upload-keystore.jks"

base64 -i "$KS" | gh secret set KEYSTORE_BASE64 --repo mdarif/alquran-app
gh secret set KEY_ALIAS      --repo mdarif/alquran-app --body "upload"
gh secret set KEY_PASSWORD   --repo mdarif/alquran-app   # paste keyPassword   from android/key.properties
gh secret set STORE_PASSWORD --repo mdarif/alquran-app   # paste storePassword from android/key.properties
```

> The keystore + passwords never enter git — they live only in Dropbox, your
> local `android/key.properties` (git-ignored), and GitHub Secrets.

### 2. Play Store upload (optional — wire up when the app exists on Play)

Create a Google Cloud service account with **Release Manager** access in the
Play Console, download its JSON key, and store it:

```bash
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT --repo mdarif/alquran-app < service-account.json
```

Until this secret exists the workflow logs a notice and skips the upload — the
signed AAB is still attached to the GitHub Release for a manual upload. Package
name on Play: `com.almarfa.al_quran`. The workflow uploads to the **internal**
track with status *completed*; promoting internal → production stays a manual
Play Console step (a deliberate human gate).

### 3. Codecov token (optional)

Public-repo coverage uploads are tokenless. If the repo is private, add
`CODECOV_TOKEN` (from codecov.io) the same way.

### 4. Branch protection

If `main` is protected, add `github-actions[bot]` to its **bypass list**
(Settings → Branches), or the version-bump push will be rejected.

## Cutting a release

From `main`, clean working tree:

```bash
make release BUMP=current   # FIRST release — ships pubspec's 1.0.0+1 as-is, tags v1.0.0
make release BUMP=patch     # bug-fix release  → 1.0.1+2, tag v1.0.1
make release BUMP=minor     # feature release  → 1.1.0+…
make release BUMP=major     # breaking release → 2.0.0+…
```

- **`current`** releases the version already in `pubspec.yaml` without bumping —
  use it once, for the first cut. Every release after that must use
  patch/minor/major so the build number (`+N` / Android versionCode) keeps
  increasing, which the Play Store requires for each upload.
- Watch the run: `make ci-logs` (failed-step logs of the latest run), or the
  Actions tab.

### Dry run

Validate the whole pipeline — including signing and the AAB build — without
tagging, releasing, pushing, or uploading:

```bash
make release-dry BUMP=patch
```

Recommended before the first real cut, to confirm the signing secrets decode and
the release build succeeds.

## What a real run does

1. Bumps `pubspec.yaml` (unless `current`).
2. Quality gate: `build_runner` codegen → `dart format` check → `flutter
   analyze --fatal-warnings` → `flutter test`.
3. Decodes the keystore from secrets and builds a signed APK + AAB.
4. Generates the changelog (git-cliff, [cliff.toml](../cliff.toml)) and Play
   "What's new" text.
5. Commits the bump (if any), tags `vX.Y.Z`, pushes both to `main`.
6. Creates the GitHub Release with the APK, AAB, and Play notes attached.
7. If `GOOGLE_PLAY_SERVICE_ACCOUNT` is set: uploads the AAB to the Play internal
   track.

## Troubleshooting

- **"Signing secrets … are not all set"** — finish step 1 above. Run
  `gh secret list --repo mdarif/alquran-app` to confirm all four are present.
- **Version-bump push rejected** — `main` is protected; add
  `github-actions[bot]` to the bypass list (step 4).
- **"Tag vX.Y.Z already exists"** — that version was already released; pick a
  higher bump.
- **Play upload failed** — the service account needs Release Manager access and
  the app must already be created in the Play Console with package
  `com.almarfa.al_quran` and at least one manual upload on the internal track.
- **Owner pre-submission gates** (not CI): translation/font/audio licensing,
  privacy-policy URL, `SCHEDULE_EXACT_ALARM` Play declaration, store assets.
  See the v1 readiness notes.
