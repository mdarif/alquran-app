# Quality backlog — reader & listener experience

Running notes of open quality items so nothing is lost between builds. Keep
adding here as we find things; move an item to **Resolved** (with the date + the
commit/test that closed it) when it ships. Severity is a rough triage, not a
promise.

Started 2026-07-08 during the audio / viewport-switch pass.

---

## Open

### 1. Last Read trails the reciter during Reading-view playback — MINOR
- **Area:** reader · audio · last-read
- **Symptom:** Listen in **Reading**, then leave/background the app → "Continue
  reading" resumes at the *page top*, up to ~7 verses (one Mushaf page) **above**
  the verse you were actually hearing. **Detailed** view is unaffected (per-verse
  accurate).
- **Root cause:** Same page-granularity as the (now-fixed) viewport-switch bug.
  Reading's reciter-follow scrolls a whole page chunk, and the debounced
  `_reportTopmost` records the topmost-**visible** verse (page top, minus the 0.04
  focus-alignment sliver → often the *previous* page's top). The reciter's exact
  verse is known — it drives the tint + peek card — but is not what gets saved as
  progress.
- **Suggested fix:** While `audioState.isSounding`, record the reciting verse as
  Last Read — e.g. a `BlocListener<AyahAudioCubit>` at `_ReaderView` level calling
  `_cubit.saveProgress(playingAyah)` on each verse change, instead of relying on the
  scroll-position report. Additive; avoids touching MushafView's flush/pin logic.
  Add a regression test (resume verse == last-heard verse, both viewports).
- **Why deferred:** Interacts with the delicate flush/pin/report machinery (many
  existing tests); kept out of the pre-build viewport-switch fix to keep that change
  tight. Flagged 2026-07-08.

### 2. Now-playing tint clears on pause (Reading view) — MINOR · decision needed
- **Area:** reader · audio
- **Symptom:** Pausing removes the sticky now-playing highlight from the Reading
  paragraph (the peek card still shows the verse). A paused listener loses the
  in-page visual anchor of where they stopped.
- **Root cause:** The paragraph tint is gated on `isSounding` (playing/buffering),
  which excludes `paused` — by design, so the ‹/› stepper is freed for browsing.
- **Decision needed (owner):** keep as-is, or keep a dimmer "paused here" tint.
  Note: the viewport-switch fix is deliberately scoped to `isSounding` for the same
  reason — if we decide a paused verse should stay "the current verse", revisit
  that scope (item 3) too.

### 3. No explicit stop / clear for audio; a paused verse stays "active" — MINOR
- **Area:** reader · audio
- **Symptom / context:** Once a verse is active it stays active (even paused) until
  you swipe to another section or leave the reader — there's no dedicated stop
  control. This is *why* the viewport-switch fix keys off `isSounding`, not
  `isActive`: an `isActive` scope would keep re-homing the view to an
  indefinitely-paused verse on every toggle.
- **Impact:** Mostly benign for v1. Revisit only if the lingering paused-active
  state ever causes confusion (e.g. add a stop affordance or auto-clear-on-idle).

---

## Pre-release gates (hard blockers — tracked elsewhere, restated so they're in one place)

### 4. Recitation licensing (Alafasy via islamic.network) — BLOCKER before store submission
- Verify licensing/attribution for the Mishary Rashid Alafasy audio streamed from
  the CDN. Already noted in `lib/core/feature_flags.dart` (`audioRecitation`) and the
  audio roadmap; must clear before release. Part of the same licensing sweep as the
  translations/fonts (see `../alquran-data/HANDOFF.md`).

---

## Resolved

- **2026-07-08 — Viewport switch mid-recitation homed to the wrong verse.**
  Toggling Reading⇄Detailed while a verse played landed on the scroll-position verse
  (up to a page behind the reciter); Detailed didn't self-correct until the verse
  finished. Fixed in `_setDetailed` (home to the sounding verse while `isSounding`).
  Covered by `test/features/reader/reader_audio_viewport_test.dart` (5 scenarios).
  See LEARNINGS.md §3.
