# Quality backlog — reader & listener experience

Running notes of open quality items so nothing is lost between builds. Keep
adding here as we find things; move an item to **Resolved** (with the date + the
commit/test that closed it) when it ships. Severity is a rough triage, not a
promise.

Started 2026-07-08 during the audio / viewport-switch pass.

---

## Open

### 2. Now-playing tint clears on pause (Reading view) — MINOR · largely superseded
- **Update (2026-07-10):** the persistent **player bar** now gives a paused verse a
  visible anchor + play/seek/stop controls that don't depend on the in-paragraph tint,
  so the "lost anchor while paused" concern is largely moot. The dimmer "paused here"
  Reading tint is still an optional consistency nicety (owner call), not a gap.
- **Area:** reader · audio
- **Symptom:** Pausing removes the sticky now-playing highlight from the Reading
  paragraph (the peek card still shows the verse). A paused listener loses the
  in-page visual anchor of where they stopped.
- **Root cause:** The paragraph tint is gated on `isSounding` (playing/buffering),
  which excludes `paused` — by design, so the ‹/› stepper is freed for browsing.
- **Now slightly inconsistent (worth resolving):** as of the paused-homing fix a
  switch DOES land you on the paused verse, and the **Detailed tile** keeps its
  now-playing tint while paused (`isActive`), but the **Reading paragraph** drops it
  (`isSounding`). So after pausing + switching to Reading you land on the right verse
  with only a brief flash, no sticky mark — and no visible play control until you tap
  the verse to reopen the peek card (Reading's only play affordance). Cheap
  consistency fix if wanted: gate the Reading paragraph tint on `isActive` too (keep a
  dimmer shade while paused), which also gives the paused verse a resume anchor.
- **Decision needed (owner):** keep as-is, or a dimmer "paused here" tint in Reading.

### 3. No explicit stop / clear for audio; a paused verse stays "active" — RESOLVED-ish
- **Update (2026-07-10):** the player bar's **close (✕)** button is now a dedicated
  Stop (`stopAll`), so there IS an explicit clear. The jump-back-to-a-long-paused-verse
  edge below only applies if you don't stop first. Keeping the note for that edge only.
- **Area:** reader · audio
- **Symptom / context:** Once a verse is active it stays active (even paused) until
  you swipe to another section or leave the reader — there's no dedicated stop
  control. This is now *leveraged intentionally*: a paused verse is still "the current
  verse", which is why a viewport switch homes to it. The only edge is a long-paused
  verse that the reader has scrolled far away from — a switch will jump back to it.
- **Impact:** Benign for v1 and the less-common flow. Revisit only if that jump-back
  ever surprises people (e.g. add a stop affordance or auto-clear-on-idle).

### 6. Reading peek card reopens on every verse during continuous playback — RESOLVED
- **Resolved (2026-07-10):** the audio-follow is now **decoupled** from the peek (the
  `_selectVerse` write was removed from the follow path), so continuous playback no
  longer opens or moves the peek card at all — the now-playing verse shows via the gold
  tint + follow-scroll + the player bar. The peek opens only on an explicit tap, so
  there's nothing to "reopen". (Left here as a pointer; see Resolved below.)

### 8. Impeller opt-out is deprecated (Flutter warns at startup) — WATCH (future Flutter upgrade)
- **Area:** rendering · Arabic · build
- **Symptom:** On launch Flutter logs "Impeller opt-out deprecated. The application
  opted out of Impeller…". The app deliberately runs on Skia (`--no-enable-impeller`
  / the manifest `EnableImpeller=false` entry) because Impeller mis-rendered Arabic
  GPOS marks (see LEARNINGS §1).
- **Risk:** a future Flutter version may remove the opt-out and force Impeller.
  Before any major Flutter upgrade, re-validate Arabic (kashida carriers, waqf marks,
  elongated madd) on Impeller across both faces; if still broken, pin Flutter or find
  a per-text workaround.
- **Not a release blocker** — informational log only; rendering is correct today
  (shipped fine through 1.1.1).

### 7. Continuous "play from here" stops at the surah end (no roll to next surah) — ENHANCEMENT
- **Area:** reader · audio
- **Symptom:** Continuous playback stops when the last verse of the surah finishes
  (`_nextAfter` returns null at the section end). A listener may expect it to flow
  into the next surah.
- **Note:** v1 is Surah-only nav, so a section = one surah. Rolling into the next
  surah needs loading the next section + repushing the sequence, and a product call
  on auto-advancing chapters. **Explicitly deferred out of the 2026-07-10 audio-player
  MVP** (owner-chosen scope) — the cubit `completed` branch is already structured so a
  future `onSequenceEnd` handoff drops in without reworking it.

### 10. Reading ‹/› stepper is still page-granular (reciter drift (d) now fixed) — UX
- **Area:** reader · reading-view · peek card
- **(d) reciter drift is RESOLVED** (2026-07-10) — the reciter-follow now scrolls the
  playing verse to the top **within the flowing paragraph** (measured negative-alignment,
  no chunk split); see Resolved below. These three **stepper** items were deliberately
  left out to keep that change tight:
  - (a) With the translation panel open, stepping ‹/› to the next verse doesn't scroll
    the surah up to reveal it — the selected verse can sit behind the (tall) card.
  - (b) With the panel minimized, stepping ‹/› across a page boundary doesn't carry the
    page + selection across gracefully.
  - (c) Tapping next repeatedly doesn't scroll progressively — the highlight advances
    but the page only moves when a chunk goes fully off screen (static, then jumps).
- **Root cause:** the ‹/› stepper still scrolls at page-CHUNK granularity via
  `_scrollToFocus(onlyIfNeeded:true)` — within a page consecutive verses map to the SAME
  chunk row, and the `_rowVisible` skip is lenient (ANY viewport overlap counts as
  visible), so the stepped verse can sit low/behind the card (a/c); cross-page
  hard-aligns the next chunk (b).
- **Approach:** route the ‹/› stepper through the same `_scrollFollowVerse` the
  reciter-follow now uses (measured negative-alignment scroll to the verse's position
  *within* the flowing paragraph, above the peek card) instead of the page-chunk
  `_scrollToFocus`. Must not re-introduce the item-9 jump (the "stepper does not
  re-scroll a visible verse" test); needs on-device tuning for card-height. Lower
  priority now that the core listening follow (d) is fixed.

---

## Pre-release gates (hard blockers — tracked elsewhere, restated so they're in one place)

### 4. Recitation licensing (Alafasy) — owner-tracked
- **Update (2026-07-10):** audio now streams from the project's **self-hosted
  Cloudflare R2** mirror (`audio.alquranreader.com`, verse-by-verse 64 kbps), not
  islamic.network. Attribution for Mishary Rashid Alafasy stays visible in the player
  (`credits_page.dart` + the bar/sheet reciter line). Licensing/attribution sign-off is
  owner-tracked alongside the translations/fonts sweep (see `../alquran-data/HANDOFF.md`).

---

## Resolved

- **2026-07-10 — Stale verse selection during playback + no session transport (audio
  player MVP).** In Reading, playing verse N then tapping another verse M left N
  highlighted **and** showed a stale Play button on M until playback transitioned —
  two unreconciled "selected verse" signals (`playingAyahId` and the tap-peek
  `_selectedAyah`) painted the **same** tint, and the reciter-follow itself wrote the
  peek field. **Fixed** by (a) splitting the tint — now-playing = **gold**
  `tertiary@0.18` (matches the Detailed tile), peek/Last-Read = **green**
  `primary@0.16` — so "what's sounding" and "what I'm inspecting" are orthogonal; and
  (b) **decoupling** the audio-follow from the peek (removed the `_selectVerse` write in
  `didUpdateWidget`), so starting playback no longer drags the peek onto the playing
  verse. On top of that, shipped the **player MVP**: a persistent mini **player bar**
  (`reader_player_bar.dart`, in the Scaffold's `bottomNavigationBar` so it's outside the
  pinch/swipe arena) + a full **player sheet** — play/pause, prev/next, a seek scrubber,
  speed (0.75–2×), repeat-verse, and a continuous toggle; speed + continuous persist
  (`ReaderSettingsRepository`). Position/duration ride the player's `progressStream`
  (NOT cubit state) so the ~5×/s scrubber tick never rebuilds the reader. The bar gives
  a paused verse a persistent anchor + an explicit Stop, and a single unambiguous
  session truth (supersedes items **2**, **3**, **6** below). Covered by
  `ayah_audio_cubit_test.dart` (transport + persistence), `reader_player_bar_test.dart`
  (bar/sheet), and the `mushaf_view_test.dart` tint-split regression. See LEARNINGS §5.
- **2026-07-10 — Reciter-follow drift + Last Read trailing in Reading (was item
  10d + item 1).** In Reading view, audio playback followed the reciter only a whole
  Mushaf PAGE at a time (`_ayahRowIndex` collapses every verse on a page to one chunk
  row, so a chunk-level `scrollTo` no-ops as the reciter advances within the page) — the
  now-playing highlight drifted down and behind the bottom peek card until the next page;
  and "Continue reading" resumed at the page top. **Shipped after two on-device
  iterations** (a per-verse chunk-split reshaped the page into blocks — rejected; details
  in LEARNINGS §3): the follow now keeps the **flowing paragraph** and scrolls the playing
  verse to the top *within* it via `_scrollFollowVerse` — SPL honors a **negative
  alignment** for a visible chunk, so `alignment = 0.04 − verseTopFraction·chunkHeightFraction`
  brings a mid-paragraph verse to the top with no split. The verse's top is **measured from
  the medallion boxes** (`rects[i-1].top`), NOT `getBoxesForSelection` on the first char
  (empty box on combining-mark Uthmani text → offset 0 → scrolls to page top; that was the
  "playing v15 shows v10" report). A ~480ms corrective re-scroll fixes off-screen targets
  (page cross / big jump). The reciter is pinned (`_heldFocusId`, released on stop/finger-
  scroll) so Last Read saves the heard verse. Kept the `_rects` reset in `_computeOffsets`
  (a latent shrink-group `RangeError` the earlier split exposed). Covered by
  `reader_audio_viewport_test.dart` (steady near-top follow across a page; the Al-Kahf
  tall-page "play v15 scrolls past v10" regression) + `mushaf_view_test.dart`. Bug 1 of two.
- **2026-07-10 — Horizontal swipe hijacked vertical scroll.** The section `PageView`
  (horizontal) wrapped the vertical reading list with no axis disambiguation — a
  diagonal/curved finger-drag won the arena on its ~18px sideways lead and turned the page
  when the reader meant to scroll. **Shipped after two dead ends** (an asymmetric
  `MediaQuery.gestureSettings` slop — an absolute threshold can't tell a curved scroll from
  a swipe at any value; and a physics-swap axis lock — the rebuild cancelled the in-flight
  scroll, "takes a couple taps"; details in LEARNINGS §3): a custom **directional**
  `_HorizontalSwipeRecognizer` (overrides `hasSufficientGlobalDistanceToAccept` to win only
  when `|dx| > _kSwipeAcceptSlop` AND `|dx| > |dy|`), so a vertical/diagonal drag never
  claims the swipe and the list always scrolls it. The PageView is `NeverScrollable` and
  driven by us (`jumpTo` on drag, `animateToPage` on release). Covered by
  `reader_swipe_test.dart` → "curved/diagonal drag scrolls, not page-turn" (multi-phase
  `TestGesture`s incl. a big-sideways-component diagonal) + the existing fling/threshold
  tests. `_kSwipeAcceptSlop` is tunable. Bug 2 of two.
- **2026-07-08 — Reading ‹/› stepper jumped the whole page (was item 9).** The
  peek card's next/prev buttons called `_scrollToFocus` unconditionally, re-aligning
  the stepped verse's Mushaf-page chunk to the top even when the verse was already on
  screen — a header lurch on a scrollable surah, an overscroll bounce on a short one
  (Al-Fatihah). Owner-confirmed clue: short surahs jump, big ones don't. Fixed by
  scoping the stepper to scroll only when the verse's chunk isn't already visible
  (`_scrollToFocus(onlyIfNeeded)` + `_rowVisible`); the reciter-follow's alignment is
  unchanged. Covered by `mushaf_view_test.dart` → "stepping a visible verse leaves the
  page put" (reproduced a 185px header jump; now 0). Shipped in 1.1.0.
- **2026-07-08 — Audio state desynced when the app was backgrounded mid-playback
  (was item 5).** Foreground-only playback (no bg-audio mode / media service) left
  the reader showing "playing" over silence after a background→return. Fixed by
  pausing on `AppLifecycleState.paused`/`hidden` — scoped to the **reader** (a
  `WidgetsBindingObserver` on `_ReaderViewState`) rather than `app.dart`, since audio
  can only sound while a reader is open and this avoids waking the lazily-registered
  player when audio was never used. New `AyahAudioCubit.pauseForBackground()` pauses
  only a *playing* verse; the player echoes `paused` so the live cubit updates to a
  truthful state (tap to resume; no auto-resume). Covered by
  `reader_audio_viewport_test.dart` → "app backgrounded during recitation" (pauses
  when playing; no-op when idle). Shipped in 1.1.0.
- **2026-07-08 — Viewport switch with a loaded verse homed to the wrong verse.**
  Toggling Reading⇄Detailed while a verse was **playing** landed on the scroll-
  position verse (up to a page behind the reciter; Detailed didn't self-correct
  until the verse finished); and while **paused** it landed one verse early (pause
  7:10 in Detailed → Reading showed 7:9). Fixed in `_setDetailed`: home to the
  player's current verse whenever one is loaded (playing/buffering/paused), carried
  in a dedicated `_pendingToggleHome` field so the outgoing view's dispose-flush
  can't clobber it mid-rebuild (it did, in one direction only — a reconciliation-order
  race). Covered by `test/features/reader/reader_audio_viewport_test.dart` (7
  scenarios: both directions × playing & paused, no-interrupt, continuous-advance,
  stopped-keeps-place). See LEARNINGS.md §3.
