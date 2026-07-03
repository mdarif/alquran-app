# Release runbook — Al Quran

One-click CD on a **develop → main promote flow**. Day-to-day work lands on
`develop` (the default branch); `main` always sits at the last release.
Cutting a release fast-forwards develop into main, runs the full quality gate,
builds a **production-signed** APK + AAB, generates a changelog, tags the
commit, publishes a GitHub Release with the artifacts attached, (optionally)
uploads the AAB to the Play Store internal track — and fast-forwards `develop`
back so the version-bump commit lands on both branches.

> Looking for the full ship-it playbook (preflight checklist, iOS, store
> submission, post-release)? See **[docs/release-runbook.md](release-runbook.md)**.
> This doc is the CD *mechanics*; that one is the *sequence you follow*.

- Workflow: [.github/workflows/flutter-release.yml](../.github/workflows/flutter-release.yml)
- Trigger: `make release-auto BUMP=<current|patch|minor|major>` from `develop`
  (or Actions → **Release** → *Run workflow* on develop with
  `confirm_promote` ticked). Escape hatch: `make release BUMP=…` from `main`.
- CI (every push/PR to `main`/`develop`): [.github/workflows/flutter-ci.yml](../.github/workflows/flutter-ci.yml)
  — codegen → format → analyze → test (+ Codecov).

## Branch model

- **`develop`** (default) — all day-to-day commits. CI gates every push.
- **`main`** — release-only. Nothing is pushed here by hand; the release
  workflow's `promote` job fast-forwards it to develop, the release lands the
  version bump + tag on it, and `sync-develop` fast-forwards develop back.
  With `bump=current` (no bump commit) the sync is a no-op.
- Both merges are **fast-forward only** — a diverged branch fails the job with
  a recovery pointer instead of guessing at a merge.
- Protection is **convention-only**: neither branch has GitHub protection
  rules, so the workflow's default `GITHUB_TOKEN` can push both. The only
  writer to `main` is the release workflow — keep it that way.

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

### 2. Play Store auto-upload (wire up once — activates from the next release)

This is the "release goes straight to Play" automation, identical to
Al-Tawheed's. The upload step is **already in the workflow**
(`r0adkll/upload-google-play`), gated on the `GOOGLE_PLAY_SERVICE_ACCOUNT`
secret — set it once and every future release auto-uploads the signed AAB to
the **internal** track. Until then the workflow logs a notice and skips (the
signed AAB is still attached to the GitHub Release for a manual upload).

**Two hard prerequisites:** the app must already exist on Play with at least one
**manual** AAB upload (a service account can't create the first release), and the
account needs **app-level "Manage testing tracks"** permission on Al Quran —
account-level release alone 403s.

**Full step-by-step** — reuse Al-Tawheed's existing service account
(recommended, ~5 min) or create a dedicated one — is in
**[docs/play-store-service-account-setup.md](play-store-service-account-setup.md)**.
The secret is the raw JSON (the workflow reads it via
`serviceAccountJsonPlainText`); it uploads to the **internal** track, and
promoting internal → **production** (with the staged rollout) stays a manual
Play Console gate.

### 3. Codecov token (optional)

Public-repo coverage uploads are tokenless. If the repo is private, add
`CODECOV_TOKEN` (from codecov.io) the same way.

### 4. Branch protection (none, by design)

Neither `main` nor `develop` carries GitHub protection rules — the promote /
bump / sync pushes all run on the default `GITHUB_TOKEN`. If you ever protect
either branch, add `github-actions[bot]` to its **bypass list** (Settings →
Branches); a *required status check* on develop would additionally need a PAT
for the sync push (Al-Tawheed's `DEVELOP_SYNC_TOKEN` pattern), because
bot-token pushes can't satisfy required checks.

## Cutting a release

From `develop`, clean working tree, CI green:

```bash
make release-auto BUMP=current   # FIRST release — ships pubspec's 1.0.0+1 as-is, tags v1.0.0
make release-auto BUMP=patch     # bug-fix release  → 1.0.1+2, tag v1.0.1
make release-auto BUMP=minor     # feature release  → 1.1.0+…
make release-auto BUMP=major     # breaking release → 2.0.0+…
```

Escape hatch — release exactly what's already on `main` (skips the promote;
develop is still synced afterwards): `make release BUMP=…` from `main`.

- **`current`** releases the version already in `pubspec.yaml` without bumping —
  use it once, for the first cut. Every release after that must use
  patch/minor/major so the build number (`+N` / Android versionCode) keeps
  increasing, which the Play Store requires for each upload.
- Watch the run: `make ci-logs` (failed-step logs of the latest run), or the
  Actions tab.

### Dry run

Validate the whole pipeline — including signing and the AAB build — against
`develop`'s code, without promoting, tagging, releasing, pushing, or uploading
(the promote and sync jobs skip themselves; `confirm_promote` isn't needed):

```bash
make release-dry BUMP=patch
```

Recommended before the first real cut, to confirm the signing secrets decode and
the release build succeeds.

## What a real run does

0. **Promote** (develop dispatch only): fast-forwards `main` to `develop` and
   hands the promoted SHA to the release job.
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
8. **Sync**: fast-forwards `develop` back to `main` so the bump commit exists
   on both branches (no-op for `bump=current`).

## Troubleshooting

- **"Signing secrets … are not all set"** — finish step 1 above. Run
  `gh secret list --repo mdarif/alquran-app` to confirm all four are present.
- **promote: "Refusing to promote develop -> main"** — dispatched from develop
  without `confirm_promote=true`. `make release-auto` always sets it; from the
  Actions UI, tick the checkbox.
- **promote: "not possible to fast-forward"** — `main` has a commit develop
  lacks (escape-hatch release or manual push). On develop:
  `git fetch && git merge origin/main` (if `pubspec.yaml` conflicts, keep the
  **higher** version), push develop, re-run.
- **sync-develop: "not possible to fast-forward"** — develop picked up commits
  mid-release. **The release itself already shipped — do not re-run the
  workflow.** On develop: `git fetch && git merge origin/main`, resolve
  `pubspec.yaml` keeping the **higher** version, push.
- **Version-bump push rejected** — `main` gained protection; add
  `github-actions[bot]` to the bypass list (step 4). (The push itself uses
  `HEAD:main` because the release job runs on a detached-HEAD SHA checkout.)
- **"Tag vX.Y.Z already exists"** — that version was already released; pick a
  higher bump.
- **Play upload failed** — the service account needs Release Manager access and
  the app must already be created in the Play Console with package
  `com.almarfa.alquran` and at least one manual upload on the internal track.
- **Owner pre-submission gates** (not CI): translation/font/audio licensing,
  privacy-policy URL, `SCHEDULE_EXACT_ALARM` Play declaration, store assets.
  See the v1 readiness notes.
