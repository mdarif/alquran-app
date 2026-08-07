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
- Trigger: `make release-auto BUMP=<patch|minor|major>` from `develop`
  (or Actions → **Release** → *Run workflow* on develop with
  `confirm_promote` ticked). Escape hatch: `make release BUMP=…` from `main`.
- CI (every push/PR to `main`/`develop`): [.github/workflows/flutter-ci.yml](../.github/workflows/flutter-ci.yml)
  — codegen → format → analyze → test (+ Codecov).

## Branch model

- **`develop`** (default) — all day-to-day commits. CI gates every push.
- **`main`** — release-only. Nothing is pushed here by hand; the release
  workflow's `promote` job fast-forwards it to develop, the release lands the
  version bump + tag on it, and `sync-develop` fast-forwards develop back.
- Both merges are **fast-forward only** — a diverged branch fails the job with
  a recovery pointer instead of guessing at a merge.
- Protection is **convention-only**: neither branch has GitHub protection
  rules, so the workflow's default `GITHUB_TOKEN` can push both. The only
  writer to `main` is the release workflow — keep it that way.

## One-time setup

The release workflow needs a few **repository secrets**. Set them once with the
GitHub CLI (`gh auth login` first). Signing is **required**; Play upload,
soft-update config publishing, and Codecov are **optional** — the pipeline skips
them cleanly when their secret is absent, so you can ship GitHub Releases today
and wire up the rest later.

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

Al Quran declares `USE_EXACT_ALARM` for precise prayer-time and Sunnah
reminders. Play only shows the exact-alarm declaration after an uploaded AAB
requests it. For the first declaration-triggering run, set:

```bash
gh secret set PLAY_EXACT_ALARM_DECLARED --repo mdarif/alquran-app --body "bootstrap"
```

If Play stops the release and surfaces the declaration, complete it in Play
Console, then change the guard secret to:

```bash
gh secret set PLAY_EXACT_ALARM_DECLARED --repo mdarif/alquran-app --body "true"
```

After that, every release stays fully automated. The workflow refuses to upload
an AAB while the secret is missing, because Play rejects the release after
consuming the version code.

### 3. Codecov token (optional)

Public-repo coverage uploads are tokenless. If the repo is private, add
`CODECOV_TOKEN` (from codecov.io) the same way.

### 4. Soft-update config publishing (optional, recommended)

Every release generates `app-update.json` from the bumped semver:

```json
{
  "latestVersion": "1.2.2",
  "minimumSupportedVersion": "1.0.0",
  "storeUrl": "https://play.google.com/store/apps/details?id=com.almarfa.alquran",
  "message": "A newer version is available.",
  "remindAfterDays": 7
}
```

The Android app reads `https://alquranreader.com/app-update.json`. That exact
path is served by a small Cloudflare Worker in `infra/app-update-worker/`
(route `alquranreader.com/app-update.json`, scoped to that one path so it
doesn't touch the rest of the alquranreader.com zone, which is otherwise the
al-quran-web Pages site) — it reads the `app-update.json` object out of the
`al-quran-editions` R2 bucket. **Root-domain R2 custom domains don't work
here**: alquranreader.com already has a Pages custom domain attached for the
website, and a bucket-level custom domain on the same root would conflict —
that's why this needs the path-scoped Worker Route instead. Deploy/redeploy
the Worker only when `infra/app-update-worker/src/index.ts` changes:

```bash
cd infra/app-update-worker && npx wrangler deploy
```

Then set the three release-workflow secrets so `flutter-release.yml` can
write the object on every release:

```bash
gh secret set CLOUDFLARE_API_TOKEN --repo mdarif/alquran-app
gh secret set CLOUDFLARE_ACCOUNT_ID --repo mdarif/alquran-app --body "..."
gh secret set APP_UPDATE_R2_BUCKET --repo mdarif/alquran-app --body "al-quran-editions"
```

After that, release runs publish the config automatically (independent of
whether the Play upload runs) and a verification step re-fetches the live
`app-update.json` and fails the release if it doesn't match the shipped
version. Older app versions show the banner on Home, `Later` hides the
same version for 7 days, and the banner stops once the installed version is
current or newer.

### 5. Branch protection (none, by design)

Neither `main` nor `develop` carries GitHub protection rules — the promote /
bump / sync pushes all run on the default `GITHUB_TOKEN`. If you ever protect
either branch, add `github-actions[bot]` to its **bypass list** (Settings →
Branches); a *required status check* on develop would additionally need a PAT
for the sync push (Al-Tawheed's `DEVELOP_SYNC_TOKEN` pattern), because
bot-token pushes can't satisfy required checks.

If `mdarif/alquran-data` is private and the default workflow token cannot read
it, add a repo secret named `DATA_REPO_TOKEN` with read access to that repo.

## Cutting a release

From `develop`, clean working tree, CI green:

```bash
make release-auto BUMP=patch     # bug-fix release  → 1.0.1+2, tag v1.0.1
make release-auto BUMP=minor     # feature release  → 1.1.0+…
make release-auto BUMP=major     # breaking release → 2.0.0+…
```

Escape hatch — release exactly what's already on `main` (skips the promote;
develop is still synced afterwards): `make release BUMP=…` from `main`.

- Every release bumps the version so the build number (`+N` / Android
  versionCode) keeps climbing, which the Play Store requires for each upload.
- Play Store notes are generated automatically from both repos by
  `tool/generate_reader_release_notes.py`. The workflow checks out
  `mdarif/alquran-data`, writes reader-friendly `play-store-notes.txt`, and
  attaches `release-note-metadata.txt` with the exact app/data commit counts.
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

### Manual Play release recovery

Use this only when Play Console forced a manual path after CI built or attempted
to upload a signed AAB — for example an App content declaration surfaced late,
an edit failed after consuming a version code, or you had to create/submit the
release in Play Console by hand.

Do **not** re-run the failed workflow with the same build number. Google Play may
have already consumed that `versionCode` even when the edit failed. If Play says
the version code has already been used, bump to the next build number, build a
fresh AAB, and upload that one manually.

After the manual Play release is live or sent for review, finish the repo/CD
state from a clean `develop` checkout:

```bash
make finalize-manual-release \
  RELEASE_VERSION=1.2.6 \
  RELEASE_BUILD=11 \
  RELEASE_AAB=build/app/outputs/bundle/release/al-quran-1.2.6+11.aab
```

The finalizer is the source-of-truth repair step. It:

- refuses to run unless the working tree is clean and you are on `develop`,
- fetches tags and refuses to reuse an existing `vX.Y.Z`,
- updates `pubspec.yaml` to `RELEASE_VERSION+RELEASE_BUILD`,
- regenerates reader-friendly Play notes from this repo plus `../alquran-data`,
- generates `app-update.json` for the shipped semver,
- publishes `app-update.json` to the `al-quran-editions` R2 bucket,
- verifies the public update URL the app reads:
  `https://alquranreader.com/app-update.json`,
- creates `chore: release vX.Y.Z`,
- creates the annotated tag `vX.Y.Z`,
- pushes the same release state to both `develop` and `main`,
- creates the GitHub Release and attaches the manual AAB, Play notes, metadata,
  and soft-update config.

If the R2 upload succeeds but the public URL does not verify, deploy the
path-scoped Worker and check the URL again:

```bash
cd infra/app-update-worker
npx wrangler deploy
curl -fsSL https://alquranreader.com/app-update.json
```

The expected JSON must contain the released version:

```json
{
  "latestVersion": "1.2.6",
  "minimumSupportedVersion": "1.0.0",
  "storeUrl": "https://play.google.com/store/apps/details?id=com.almarfa.alquran",
  "message": "A newer version is available.",
  "remindAfterDays": 7
}
```

Before closing the manual release, verify:

```bash
git fetch origin --tags
git log --oneline --decorate -n 3
git log origin/develop..origin/main
gh release view v1.2.6 --repo mdarif/alquran-app --web
curl -fsSL https://alquranreader.com/app-update.json
```

`origin/develop..origin/main` should print nothing, the GitHub Release should
show the AAB plus generated files, and the live JSON should advertise the
released version.

## What a real run does

0. **Promote** (develop dispatch only): fast-forwards `main` to `develop` and
   hands the promoted SHA to the release job.
1. Bumps `pubspec.yaml` per the chosen bump.
2. Quality gate: `build_runner` codegen → `dart format` check → `flutter
   analyze --fatal-warnings` → `flutter test`.
3. Decodes the keystore from secrets and builds a signed APK + AAB.
4. Generates the GitHub changelog (git-cliff, [cliff.toml](../cliff.toml)) and
   reader-friendly Play "What's new" text from the app + data repo histories.
5. Generates `app-update.json` from the bumped semver and publishes it when the
   Cloudflare secrets are configured.
6. Commits the bump, tags `vX.Y.Z`, pushes both to `main`.
7. Creates the GitHub Release with the APK, AAB, Play notes, and update config
   attached.
8. If `GOOGLE_PLAY_SERVICE_ACCOUNT` is set: uploads the AAB to the Play internal
   track.
9. **Sync**: fast-forwards `develop` back to `main` so the bump commit exists
   on both branches.

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
  If the error says the exact-alarm declaration is missing, complete the Play
  Console declaration and set `PLAY_EXACT_ALARM_DECLARED=true`. If App content
  is blank because Play has not surfaced the form yet, set
  `PLAY_EXACT_ALARM_DECLARED=bootstrap` for one release attempt. Do **not**
  upload the same AAB manually after a failed Play edit; its version code may
  already be consumed. Bump to the next build number and re-run the release, or
  use [Manual Play release recovery](#manual-play-release-recovery) if the Play
  Console release has already been completed manually.
- **Owner pre-submission gates** (not CI): translation/font/audio licensing,
  privacy-policy URL, `SCHEDULE_EXACT_ALARM` Play declaration, store assets.
  See the v1 readiness notes.
