# Mobile performance roadmap

Measured performance work for the core reading experience. This is a quality
track, not feature expansion: the goal is for Home, reader opening, vertical
reading, surah paging, viewport changes, zoom, and audio to feel immediate and
stable on real devices.

## Baseline: 2026-08-04

Profile-mode build using the production dependency graph and bundled 27 MB
`quran.db` on a physical OnePlus CPH2767 (Android 16, 1272x2800, 560 dpi). The
display rendered at 90 Hz during the run, giving the app an 11.1 ms frame budget.
The scripted journey used Al-Baqarah and exercised Home scrolling, reader open,
Reading scroll, three real RTL surah advances, pinch zoom, Detailed open and
scroll, and real streamed audio startup.

The benchmark is `test_perf/reader_perf_test.dart`; run it with:

```bash
make perf DEVICE=<physical-device-id>
```

| Journey | Build p90 / max | Raster p90 / max | Result at 90 Hz |
| --- | ---: | ---: | --- |
| Home scroll | 3.7 / 8.8 ms | 3.4 / 11.3 ms | Healthy |
| Reader open | 11.4 / 43.3 ms | 31.3 / 35.1 ms | Visible hitch |
| Reading scroll | 1.4 / 20.7 ms | 3.6 / 44.0 ms | Smooth body, isolated spikes |
| Surah swipe | 2.3 / 27.9 ms | 4.0 / 5.5 ms | Build-side page-change hitch |
| Pinch zoom | 13.5 / 32.1 ms | 30.8 / 33.0 ms | Consistently misses 90 Hz |
| Detailed open | 13.7 / 40.4 ms | 38.0 / 56.4 ms | Worst transition |
| Detailed scroll | 0.9 / 28.6 ms | 2.5 / 53.5 ms | Smooth body, severe outliers |
| Audio start | 11.0 / 11.0 ms | 33.2 / 33.2 ms | One startup hitch |

The values above are from the final corrected run. Two earlier runs reproduced
the same shape: Home stayed healthy; swipe peaked around 30 ms; pinch reached
28-52 ms; Detailed open reached 34-41 ms or worse. This makes the priorities
repeatable rather than a one-run anomaly.

Android diagnostics after the full warmed journey:

- Total PSS: 285 MB; total RSS: 432 MB.
- Graphics PSS: 72 MB; Skia GPU surfaces: about 54 MB at native resolution.
- Native heap: 49 MB PSS / 60 MB allocated.
- Android `gfxinfo`: 2.86% janky frames, 27 high-input-latency reports, one
  81 ms frame.
- A concurrent GC during the diagnostics window took 16.8 ms.
- Device thermal status remained normal, so throttling did not explain the
  outliers.

Real Android process launch through `main.dart` measured 585 ms on first launch
including seed setup and 449 ms on a subsequent cold process start. Startup is
acceptable on this device, but must still be measured on a mid-range Android
before being declared complete.

## Performance budgets

For repeated gestures, use the device refresh budget, not only the conventional
60 Hz threshold:

- 90 Hz target: p90 build and raster under 11.1 ms; no repeated frame above
  22.2 ms.
- 60 Hz floor: p99 under 16.7 ms for Home and steady-state reader scrolling.
- Core transitions: no build or raster frame above 33.3 ms.
- Warmed **release** reader memory: below 220 MB PSS on this device, followed by a
  device-class budget after measuring a mid-range phone. Profile-mode memory is
  diagnostic only and must not be used as the shipping gate.
- Cold launch: under 800 ms on this device and under 1.5 s on the mid-range test
  device, including notification/audio initialization.

## Work order

## Optimization log

### 2026-08-04 - Audio rebuild isolation

- Removed `AyahAudioCubit` state from above the reader `PageView`.
- Reading now rebuilds only the interactive Mushaf surface when the playing ayah
  changes; speed/repeat/status-only changes do not rebuild Quran text.
- Detailed mode rebuilds only ayah tiles whose active/loading/playing/error visual
  state changed.
- All 41 targeted audio, viewport, swipe, and tile regressions pass; static
  analysis is clean.
- Profile runs showed swipe build max between 19.6 and 31.3 ms versus a 27.9 ms
  baseline. Audio-start raster varied between 9.3 and 38.8 ms because the phase
  also includes first ExoPlayer/codec/network initialization. Treat neither as a
  stable win until the benchmark separates player startup from widget rebuilds.
- The benchmark now forces pinch to start at 28 pt and restores the owner's font
  preference in teardown. Earlier no-op pinch results at the persisted 48 pt
  maximum are excluded.

### 2026-08-04 - Pinch preview with one text reflow

- Pinch movement now transforms a cached viewport instead of changing the Arabic
  font on every pointer event. The rounded font is committed and persisted once
  when the gesture settles.
- The existing page lock remains active until every finger lifts, preserving the
  guarantee that a pinch cannot turn into a surah swipe.
- On the 90 Hz OnePlus at the controlled 28 pt starting size, build max improved
  from 33.8 ms to 17.4 ms. Ten of eleven measured frames stayed below 8 ms; the
  only frame above 16 ms was the final text reflow.
- Adding a `RepaintBoundary` under the transform reduced raster p90 from 32.6 ms
  to 20.2 ms and max from 37.3 ms to 32.3 ms. Three raster frames still exceeded
  16 ms, so full-screen layer composition and the final Arabic repaint remain a
  measured follow-up rather than a completed 90 Hz target.
- All 42 targeted pinch, last-read, viewport, swipe, and audio regressions pass;
  static analysis is clean.

### 2026-08-04 - Direct Detailed-view positioning

- Detailed mode now mounts `ScrollablePositionedList` directly at the active
  verse instead of first laying out row zero and running a 450 ms post-frame
  scroll to the target.
- Exact Last Read position, focus highlight, viewport toggles, script changes,
  and animated reciter-follow behavior are preserved. All 57 targeted reader
  regressions pass; static analysis is clean.
- On the physical 90 Hz OnePlus, Detailed-open frame count fell from 11 to 8,
  build p90 from 14.3 ms to 1.3 ms, and raster p90 from 33.7 ms to 18.3 ms.
  Build max improved from 38.6 ms to 33.5 ms and raster max from 35.5 ms to
  32.8 ms. The remaining first-layout frame is still above the transition budget
  and needs component-level attribution.

### 2026-08-04 - Detailed scroll layer simplification

- Added per-fling benchmark output to distinguish recurring scroll stalls from
  one transition or system animation.
- Detailed mode already isolates the visible page for screenshot capture. The
  positioned list's additional automatic boundary around every ayah was removed,
  avoiding a nested stack of composited Arabic/translation text layers.
- On the physical 90 Hz OnePlus, aggregate Detailed-scroll raster max fell from
  54.9 ms to 15.5 ms, p99 from 31.3 ms to 8.8 ms, and frames over 16 ms from five
  to zero. All six individual flings stayed below 16 ms raster time.
- Median raster increased from 2.1 ms to 2.6 ms and p90 from 2.5 ms to 4.8 ms,
  still comfortably inside the 11.1 ms device budget. This is the intended
  tradeoff: modest steady paint work instead of severe isolated stalls.
- Two measured experiments were rejected and reverted: making the screenshot
  boundary on-demand left five raster stalls and added capture complexity;
  caching one viewport ahead also left five stalls and shifted extra work into
  list construction.

### 2026-08-04 - Silent speculative section prefetch

- Automatic previous/next section prefetch now fills ReaderCubit's cache without
  incrementing `cacheEpoch`. Explicit `warm()` calls from a visible cache-miss
  spinner still notify, so fast-swipe recovery behavior is unchanged.
- This prevents unrelated background database completions from rebuilding the
  active Quran `PageView` during a gesture. All 47 cache, LRU, fast-swipe,
  viewport, and resume regressions pass; static analysis is clean.
- On the physical OnePlus, Detailed-scroll build frames over 16 ms fell from four
  to three, max from 31.6 ms to 28.9 ms, and aggregate p99 from 25.0 ms to 8.1 ms.
  The remaining isolated build frames occur as new variable-height translation
  rows are first constructed and laid out; they are separate from the resolved
  background-prefetch rebuilds and raster stalls.

### 2026-08-04 - Release memory baseline

- Added an opt-in 60-second diagnostics window to the physical benchmark via
  `--dart-define=PERF_DIAGNOSTICS_PAUSE=true`; normal runs remain unchanged.
- The fully warmed profile process measured 272.6 MB PSS / 423.1 MB RSS, down
  from the original 285 MB / 432 MB profile baseline after layer simplification.
- A shipping release APK was then installed and warmed through real Al-Baqarah
  Reading, Detailed scrolling, and audio initialization. It measured 177.8 MB
  PSS / 325.3 MB RSS: graphics 61.9 MB, native heap 38.1 MB, and code 32.5 MB.
- Release memory is 42.2 MB below the 220 MB gate. The earlier concern was mostly
  profile runtime/code overhead: profile PSS was about 95 MB higher under a
  comparable warmed journey.
- This journey retains only the active and neighbouring sections, so neither the
  repository's 40-entry ceiling nor ReaderCubit's 7-entry ceiling is saturated.
  Keep both for swipe/reopen latency until a deliberate cache-saturation test
  proves retained Quran data, rather than runtime graphics, is a real pressure.

### 2026-08-04 - Release startup baseline

- Measured the installed release APK with Android ActivityManager rather than
  inferring shipping startup from `flutter drive` profile timings.
- Five forced cold launches completed in 184, 196, 210, 213, and 253 ms
  (`TotalTime`; median 210 ms, worst 253 ms).
- Five warm task resumes completed in 12-15 ms (`WaitTime`). Cold launch is
  547 ms inside the 800 ms device gate; warm resume is effectively immediate.
- No startup lifecycle change was made. Moving timezone/notification setup after
  `runApp` would create a race with launch-time reminder rescheduling and tapped
  notification routing for negligible measured benefit. Revisit only if a
  slower mid-range device or first-install seed measurement fails its gate.

### 2026-08-04 - Audio feedback isolation

- Split the physical benchmark's old two-second `audio-start` phase into the
  immediate `audio-feedback` frame and subsequent `audio-ready` work.
- On the OnePlus, tap-to-loading feedback built in 0.7 ms and rastered in 2.8 ms,
  comfortably inside the 11.1 ms interaction budget.
- Android's later ExoPlayer/MediaCodec initialization produced a 36.0 ms raster
  frame while loading; it is not a delayed Flutter feedback frame. The visible
  spinner is already active before that work begins.
- No decoder prewarm was added. It would shift codec initialization into reader
  opening, retain audio resources for users who never press Play, and compete
  with Quran layout. Reconsider only if a future player API supports a measured,
  low-cost prepare path or device testing shows delayed audible playback rather
  than one isolated readiness frame.

### 2026-08-04 - Three-run physical-device release gate

Ran the complete profile journey three consecutive times on the physical 90 Hz
OnePlus after all changes above. Every run passed. The table reports the median
of each run's p90 and the worst single frame across all three runs.

| Journey | Build median p90 / worst max | Raster median p90 / worst max | Gate |
| --- | ---: | ---: | --- |
| Home scroll | 3.7 / 8.7 ms | 3.4 / 16.4 ms | Pass |
| Reader open | 11.9 / 41.7 ms | 30.7 / 39.4 ms | Follow-up |
| Reading scroll | 1.4 / 21.1 ms | 3.5 / 42.5 ms | Follow-up outlier |
| Surah swipe | 2.2 / 32.3 ms | 3.4 / 5.4 ms | Pass steady state |
| Pinch | 5.2 / 19.9 ms | 33.8 / 51.0 ms | Follow-up |
| Detailed open | 1.2 / 40.3 ms | 35.3 / 42.4 ms | Follow-up |
| Detailed scroll | 1.5 / 33.0 ms | 4.7 / 17.6 ms | Pass steady state |
| Audio tap | 4.5 / 4.7 ms | 36.2 / 37.1 ms | Platform startup outlier |

- Profile startup wall time was 484-488 ms (median 487 ms). Shipping startup
  remains governed by the separately measured release median of 210 ms.
- Home had no build frame above 16 ms in 957 frames. Surah paging had no raster
  frame above 8 ms in 299 frames.
- Detailed scrolling had one raster frame above 16 ms in 885 frames, with a
  17.6 ms worst case. The original baseline reached 53.5 ms, so the severe raster
  stalls are resolved. New variable-height rows still cause isolated 20-33 ms
  build frames and remain the next useful optimization target.
- The audio tap's Flutter build work stayed below 4.7 ms. On these runs the codec
  began quickly enough to land a 35.5-37.1 ms raster frame inside the nominal
  feedback window; keep interpreting this with the ExoPlayer/MediaCodec logs,
  not as a slow loading-state rebuild.
- The final gate therefore closes the broad performance pass, but does not claim
  every strict 90 Hz transition budget is met. Remaining work is narrowly scoped
  to first Arabic layout/composition, pinch settle paint, and first construction
  of Detailed rows.

### P0 - Benchmark guardrails

1. Keep the physical-device profile benchmark non-destructive: never clear
   preferences, bookmarks, reminder choices, or reading position.
2. Emit machine-readable results and fail only after stable budgets are agreed.
3. Add separate cold-start, warm-start, first-install seed, warmed-memory, and
   repeated-run capture scripts.
4. Establish a second baseline on a representative mid-range Android device and
   an iPhone before release sign-off.

### P1 - Reader transition and gesture hitches

1. Isolate audio rebuilds below the `PageView`; remove the overlapping whole-page
   and per-ayah rebuild paths.
2. Attribute the remaining pinch raster frames from full-screen layer scaling
   and the final text reflow; build-side repeated reflow is resolved.
3. Profile `_MarkedParagraph` shaping, medallion measurement, overlay layout, and
   paint separately. Cache stable spans and marker metadata where measurement
   proves a gain.
4. Prebuild only the immediately adjacent section after idle so the first real
   swipe does not construct Arabic layout under the finger.
5. Attribute and reduce the remaining first-layout frame when constructing the
   Detailed representation; duplicate animated positioning is resolved.

### P2 - Scroll outliers and memory

1. Attribute the 44-54 ms raster outliers with Flutter timeline traces and Skia
   tracing; check first exposure of new glyphs, large repaint boundaries, and
   system-bar/chrome animations.
2. Add a deliberate 40-section cache-saturation release test before changing the
   repository or ReaderCubit limits; normal warmed release memory is within gate.
3. Reassess the full-screen Detailed `RepaintBoundary`, which is useful for
   screenshot sharing but may retain expensive native-resolution surfaces.
4. Coalesce page-pill, item-position, immersion, and last-read updates so an idle
   settle does not trigger unrelated work.
5. Persist Last Read as one record rather than seven sequential preference writes.

### P3 - Startup and platform polish

1. Split first useful frame from best-effort notification, timezone, catalogue,
   Hijri, and audio initialization where correctness allows.
2. Measure first-install and database-version-update seed copies on slower storage.
3. Android predictive back app support is complete: the manifest opts into
   `OnBackInvokedCallback`, Reader Settings now uses a predictive-compatible
   `MaterialPageRoute`, and the app already uses `PopScope` for Home search.
   On the physical Android 16 device, edge back correctly navigated Settings ->
   Reader -> Home; with search focused, Android first dismissed the IME and the
   next gesture closed search without exiting Home. The former callback-not-enabled
   warning is gone. OxygenOS reports predictive animation disabled at the system
   level (`enable_back_animation` is unset), so preview-frame animation still
   needs visual sign-off on an enabled Android 13+ device or emulator.
4. Tune custom scroll spring and page-settle duration through side-by-side device
   builds after frame hitches are fixed, so motion feel is judged separately from
   dropped frames.

## Release gate

Do not call the performance track complete from simulator, debug-mode, or widget
test results. Before the next release candidate, run the scripted profile journey
three times per physical device, report median and worst run, inspect one timeline
for every failing journey, and compare against this baseline. Correctness tests
remain mandatory; performance work must not regress RTL paging, curved-drag
disambiguation, exact resume position, pinch accessibility, or audio follow.
