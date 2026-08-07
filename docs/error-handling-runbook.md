# Error handling runbook - Al Quran

This document is the reliability map for Al Quran. The rule of thumb is simple:
the bundled Quran reader must keep working offline; optional network/platform
features should fail calmly, explain only what helps the reader, and leave a
clear retry path.

## Reader-facing principles

- Never show raw exception text to readers.
- Keep the Quran text, bundled translations, reading settings, bookmarks, and
  last-read usable even when every remote service is down.
- Use inline retry states for optional remote content.
- Use snackbars only for short-lived action failures.
- Use dialogs only for explicit user actions or blocking/required updates.
- Treat offline as normal, not exceptional.
- Prefer stale-but-valid cached catalogues over empty screens.
- Never install downloaded content unless integrity checks pass.
- Add diagnostics at boundaries so a real device can be debugged quickly.

## Failure inventory

| Area | Dependency | Failure scenarios | Current behavior | Gap / target behavior |
|---|---|---|---|---|
| Soft update config | `https://alquranreader.com/app-update.json`, Cloudflare Worker, R2 | no internet, DNS failure, Worker down, R2 object missing, non-2xx, malformed JSON, stale config, Play Store URL invalid | Repository now distinguishes available / up-to-date / error in local work; live JSON is verified by release pipeline | Finish shared `AppUpdateCubit` flow; Home and Settings must use the same state; manual check must show available / current / could not check; log current/latest/status/dismissed |
| Play Store open | Android intent / browser | Play Store missing, no browser, `launchUrl` returns false | Home banner and Settings update action call `launchUrl` | Check return value and show a fallback with copyable/store URL or browser fallback |
| Translation catalogue | `https://editions.alquranreader.com/catalogue.json`, R2/CDN | offline, non-200, malformed JSON, cache unreadable, empty catalogue, hidden/retracted edition | Falls back to cached catalogue; if first run and no cache, `catalogueUnavailable=true`; bundled/installed editions remain visible | Add clearer first-run offline copy and retry; diagnostics for HTTP/cache/parse failures |
| Translation download | edition `.db.gz` artifact | 404/500, timeout/slow stream, partial download, gzip decode failure, sha256 mismatch, expanded sha mismatch, wrong slug, no rows, temp file write/delete failure, local DB replace failure, storage full | Digest checks, expanded digest checks, slug/no-row guard, temp DB cleanup, row moves to failed with error | Make row error reader-friendly; expose retry; log failure category without raw digest noise in UI |
| Tafsir catalogue | `https://editions.alquranreader.com/tafsir/catalogue.json` | same as translation catalogue | Falls back to cached catalogue; `catalogueUnavailable=true` on failure | Match Translation UX exactly; add retry and diagnostics |
| Tafsir download | tafsir `.db.gz` artifact | same as translation download plus wrong ayah count | Digest checks, expanded digest checks, slug guard, ayah-count guard, failed item state | Reader-friendly row error; retry; log failure category |
| Audio recitation | `audio.alquranreader.com` / R2 source via `alafasyUrl`, `just_audio`, on-disk cache | no internet, CDN 404/500, stream starts then fails, corrupt cached/partial file, cache write denied/full, player init failure, interruption, app background | Emits `RecitationStatus.error`; partial cache file is deleted on play failure; prefetch is best-effort and silent | Show a small retry affordance/message on the failed verse; distinguish offline/network from player failure in diagnostics; consider timeout around prefetch/play source setup |
| Share ayah / share app | `share_plus`, temp file writes | no share target, temp file write fails, plugin throws | Caught silently in some places | Show a short snackbar for explicit share actions when they fail |
| Prayer location | Geolocator / OS location settings | permission denied, permanently denied, services off, no last known location, extreme latitude/no computable times, timezone/date rollover | `PrayerTimesCubit` emits location status or `timesUnavailable`; UI hides/adjusts prayer surface | Confirm UI copy for each status; add diagnostics for status transitions |
| Salat notifications | notification permission, exact alarm, battery settings, local notification plugin | permission denied, exact alarm denied/refused, OEM app-level ring/vibrate off, battery optimization, raw sound missing, scheduling failure, reboot/app update reschedule failure | Cubit exposes permission/delivery status; debug sound and delivery tests exist; scheduler catches many platform failures | Keep reliability panel visible when enabled; log schedule failures; avoid silent catch for user-triggered scheduling/test actions |
| Sunnah reminders | local notification plugin, settings prefs | permission denied, scheduling failure, app update/reboot re-arm failure | Similar scheduler path | Audit UI feedback parity with Salat notifications |
| Seed database | bundled `assets/db/quran.db`, version marker, app docs dir, Drift | asset missing/corrupt, copy fails, marker mismatch, Drift open fails, migration mismatch | Seeder recopies on marker change; app startup can fail if DB cannot open | Add a friendly fatal screen for DB-open failure if feasible; add diagnostics with DB marker/path |
| Downloaded editions DB | `editions.db` | migration failure, corrupted DB, installed metadata without rows | Separate DB protects downloads from seed overwrite | Add recovery path: ignore broken installed edition and allow reinstall; log slug |
| Tafsir DB | `tafsir.db` | migration/corruption, selected resource missing | Installed Tafsir read through repository | Add recovery path similar to editions |
| Home widget | `home_widget` plugin and Android receivers | plugin throws, receiver missing, stale payload, update after app upgrade, platform unavailable | Best-effort publisher, tests around expected providers | Keep best-effort; add diagnostics only, no reader-facing error |
| External links | privacy, support, source URLs, developer site | browser missing, bad URL, launch returns false | Mostly direct launch or best-effort | Check return values for explicit taps; show "Could not open link" snackbar |
| App lifecycle startup | DI, notification launch payload, Cubit refreshes | plugin throws, payload malformed, dependency not registered | Several best-effort catches | Add boundary logging; ensure startup continues where possible |

## UX surface rules

Use these consistently:

- **Home banner**: only for update availability. Optional updates can be
  dismissed. Required updates cannot.
- **Settings manual check**: always ends in an in-app result: update available,
  up to date, or could not check.
- **Translations / Tafsir pages**: inline row-level failures with Retry. The
  page itself should still show bundled and installed content.
- **Audio**: verse-level failure with retry; do not interrupt the rest of the
  reader.
- **Location / notification permissions**: actionable settings buttons, not
  generic errors.
- **External links/share**: snackbar on explicit tap failure.
- **Fatal data failure**: rare full-screen recovery message only when bundled
  reading cannot start.

## Diagnostics standard

Each boundary should log a short structured message with:

- feature name, for example `AppUpdate`, `Editions`, `Tafsir`, `Audio`,
  `PrayerNotifications`;
- operation, for example `catalogue`, `install`, `play`, `schedule`;
- stable identifiers, for example version, slug, ayah id, HTTP status;
- exception type/message for developer logs only.

Do not log downloaded Quran/Tafsir text content.

## Implementation plan

### Phase 1 - update experience and link failures

- Finish the shared `AppUpdateCubit` path already started locally.
- Ensure Home and Settings use the same update state.
- Keep the existing rule: `Later` suppresses only the same `latestVersion`.
- Add manual-check dialogs for available/current/error.
- Check `launchUrl` return values for Play Store and source/support links.
- Tests:
  - dismissed `1.2.6` does not hide `1.2.7`;
  - manual check available/current/error;
  - Play Store launch failure shows fallback.

### Phase 2 - downloadable content resilience

- Normalize Translation and Tafsir failure copy.
- Add retry from failed rows.
- Add diagnostics around catalogue fallback, digest mismatch, gzip failure,
  wrong slug, empty rows, and DB replace failures.
- Tests:
  - first-run catalogue unavailable still shows bundled/installed content;
  - cached catalogue survives malformed remote;
  - corrupt artifact leaves no installed rows and row can retry;
  - hidden catalogue entry does not remove already installed usable content
    unless intentionally hidden in UI.

### Phase 3 - audio CDN and cache resilience

- Add user-visible retry state for failed verse playback.
- Add diagnostics for audio source setup, stream errors, cache delete failures,
  and prefetch failures.
- Consider a timeout around initial source setup so a hanging CDN does not leave
  the UI spinning indefinitely.
- Tests:
  - play failure marks only that ayah as failed;
  - tapping again retries;
  - continuous playback stops cleanly or skips only by explicit design;
  - corrupt partial cache is removed.

### Phase 4 - prayer/location/notification reliability

- Audit all permission states and copy.
- Make user-triggered test/schedule failures visible.
- Keep OEM reliability instructions in the Salat notification panel.
- Tests:
  - location denied/permanently denied/service off;
  - exact alarm denied;
  - notification permission denied;
  - scheduler failure returns a readable report.

### Phase 5 - startup/data recovery

- Add a minimal fatal/recovery screen if the bundled database cannot open.
- Add diagnostics for seed copy and marker mismatches.
- Add recovery behavior for corrupted downloaded edition/Tafsir DB rows where
  possible: ignore broken resource, allow reinstall.
- Tests:
  - seed marker update recopies DB;
  - broken downloaded edition does not break bundled reading;
  - app surfaces a clear fatal state if bundled DB is unavailable.

## Priority order

1. Shared app-update state and manual-check UX.
2. Translation/Tafsir catalogue/download retry and copy.
3. Audio CDN/cache retry state.
4. External link/share launch fallbacks.
5. Notification/location failure copy audit.
6. Fatal DB recovery screen.

## Release checklist additions

Before every release:

- `curl -fsSL https://alquranreader.com/app-update.json`
- Open Translations with Wi-Fi off: bundled/installed content still visible.
- Open Tafsir with Wi-Fi off: installed Tafsir still usable, available list has
  a calm offline state.
- Try one uncached audio verse with Wi-Fi off: verse shows retry/error, reader
  remains usable.
- Tap Play Store/update link with a test launcher failure if possible.
- Run Salat notification sound check on a physical Android device.
