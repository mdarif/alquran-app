# Shared mobile performance guidance

Apply this section when building, reviewing, or optimizing Flutter mobile apps.
Repository-specific instructions and measured evidence take precedence.

## Performance workflow

- Audit before optimizing. Reproduce the user's real journey with production
  data on a physical device and record a baseline before changing code.
- Use profile mode for Flutter frame timings and release mode for shipping
  startup and memory. Debug timings and emulator smoothness are not release
  evidence.
- Budget against the device refresh rate: 90 Hz gives 11.1 ms per frame, 120 Hz
  gives 8.3 ms, and 60 Hz gives 16.7 ms. Report build and raster separately.
- Run the same journey at least three times. Report median p90 and worst max;
  do not declare a win from one favorable trace.
- Split journeys into named phases such as startup, list scroll, route open,
  horizontal paging, pinch, detailed-list scroll, and audio feedback. Aggregate
  numbers alone hide the interaction that caused a stall.
- Capture per-gesture timings when an aggregate phase contains several flings or
  swipes. This distinguishes recurring stalls from one first-use frame.
- Keep performance tests non-destructive in code. On Android, also account for
  signing: `flutter drive --profile` may uninstall a release-signed app when the
  profile key differs, which erases its app sandbox. Obtain explicit approval,
  use a dedicated test device where possible, and restore the release build.
- Change one performance variable at a time, rerun correctness tests, and retain
  rejected experiments in the audit notes so they are not repeated later.

## Flutter implementation rules

- Scope reactive rebuilds below stable navigation and paging widgets. Audio,
  progress, selection, and loading ticks must not rebuild or remount a whole
  `PageView`, route, or long text surface.
- Use `BlocBuilder.buildWhen`, selectors, or equivalent so only widgets whose
  visible state changed rebuild. Background cache fills should remain silent
  unless the visible UI is waiting for them.
- Preserve widget tree shape across modes. Conditional wrappers around stateful
  paging or scrolling widgets can remount controllers and lose position.
- For expensive text pinch zoom, composite a cached `RepaintBoundary` with a
  transform while fingers move, then perform one text reflow when the gesture
  settles. Keep accessibility bounds and persisted values correct.
- Do not add repaint boundaries by reflex. Nested per-row boundaries inside an
  already isolated full-screen surface can retain large layers and worsen raster
  outliers. Measure both steady p90 and worst frames before keeping one.
- Mount long variable-height lists directly at a known resume index. Avoid
  building row zero and then running a post-frame animated jump to the target.
- Prefetch data separately from prebuilding widgets. Warm only adjacent data,
  do it after visible work, cap caches, and avoid notifying listeners for
  speculative completions.
- Treat build and raster stalls differently. Build stalls usually point to
  rebuilds, text shaping, row construction, or layout; raster stalls point to
  painting, oversized layers, clipping, transforms, shadows, or native surfaces.
- Do not optimize an average while leaving severe max-frame stalls. A small
  increase in steady paint cost can be worthwhile when it removes repeated
  40-50 ms outliers.

## Platform and lifecycle rules

- Measure release memory only after a realistic warmed journey. Record PSS/RSS
  and graphics/native/code breakdowns; profile runtime overhead can materially
  overstate shipping memory.
- Measure cold process launch separately from warm task resume and first-install
  database/asset seeding. Do not move correctness-critical initialization after
  `runApp` unless the measured launch cost justifies the lifecycle race.
- Separate immediate UI feedback from native readiness for audio, camera, maps,
  and codecs. ExoPlayer/MediaCodec work may produce a platform raster spike even
  when Flutter displays loading feedback promptly. Do not prewarm expensive
  native resources without measuring latency, memory, and contention tradeoffs.
- For Android predictive back, opt into `OnBackInvokedCallback`, use `PopScope`,
  and use predictive-compatible routes. Verify real edge gestures; OEM settings
  may disable preview animation even when app navigation semantics are correct.

## Release gate

- Require correctness tests and static analysis after every retained change.
- Before release, repeat the scripted physical-device journey three times and
  compare it with the baseline. Inspect a timeline for every failed phase.
- Test at least one representative mid-range Android device and one iPhone
  before claiming broad performance quality. A flagship result is not a
  device-class guarantee.
- Document what still misses budget. "Improved" and "complete" are different
  claims.
