# Translation Audio Chaining Plan (Detailed Mode)

Status: **Phase 2 (Al-Fatihah POC) built and verified on-device 2026-08-08**
(iOS simulator — Arabic + Sahih International chained correctly through all 7
verses). `FeatureFlags.translationAudioFatihaPoc = true`. **Phase 1 (R2
publish of the 7 Al-Fatihah files) landed and verified live 2026-08-08**
(`al-quran-audio` bucket, `translation-audio/en-sahih-international/`
prefix). **Phase 1.5 (app-side switch off the bundled asset) also done
2026-08-08** — the translation-audio player now streams + caches from R2
via `LockCachingAudioSource`, same pattern as Arabic recitation; the 7
bundled MP3s are deleted, no longer in `pubspec.yaml`. The full 6236-file
Sahih International publish is a separate follow-up in `alquran-data`
(`docs/translation-audio-full-quran-plan.md`) — the app's chaining is still
scoped to Al-Fatihah only (`isFatihaPocAyah`) regardless of how much audio
is live on R2. Builds on the
existing [dual-audio-urdu-poc-plan.md](dual-audio-urdu-poc-plan.md) POC
(Arabic + one Urdu translation, Al-Fatihah only) but generalizes it to **any
number of audio-backed translations**, sourced from QuranEnc.com and
everyayah.com rather than an unverified community mirror, and covers both
single-ayah and continuous playback. See "Phase 2 status" below for exactly
what's built vs. still open before Phase 3.

## Goal

In Detailed mode, when the reader has one or more translation audio tracks
enabled, play each ayah as a chain:

```
Arabic (selected reciter)
  → Translation-audio #1 (if enabled and available for this ayah)
  → Translation-audio #2 (if enabled and available for this ayah)
  → ... (in a fixed priority order, not display order)
```

If zero translation-audio toggles are on, behavior is byte-for-byte identical
to today's Arabic-only playback — this feature must be additive, never a
regression to the existing recitation feature.

## Source data confirmed (2026-08-07/08, in `alquran-data`)

Two sources evaluated, both per-ayah `SSSAAA.mp3` (or manifest-listed
equivalent), both distinct from Qur'an recitation — this is a narrator
reading the *translation* aloud:

| Source | Edition | Completeness | Approx. size |
|---|---|---|---|
| QuranEnc.com (`d.quranenc.com/data/audio/<key>/files.json`) | `english_rwwad` (Rowwad Translation Center) | 6236/6236 | ~795 KB/ayah avg → **~5 GB** total |
| QuranEnc.com | 10 other complete languages (Assamese, Chinese-Suliman, Dutch, French-Rashid, Persian, Portuguese, Sinhalese, Somali, Tagalog, Vietnamese) | 6236/6236 each | ~5 GB each |
| QuranEnc.com | `azeri_musayev` (Azerbaijani) | **3736/6236 — incomplete** | n/a, exclude until fixed upstream |
| everyayah.com (`everyayah.com/data/English/<slug>/`) | `Sahih_Intnl_Ibrahim_Walk_192kbps` (Sahih International) | 6236/6236 (fetch in progress as of this doc) | ~130-170 KB/ayah avg → **~1-1.5 GB** total |

Owner decision 2026-08-07/08: fetch **Sahih International** (everyayah.com)
now; **defer** `english_rwwad` (QuranEnc) pending compression, since at ~5 GB
it's ~3-4x the size of the everyayah alternative for comparable content
(English translation audio). Pilot fetch scripts live in `alquran-data`:
`pipeline/quranenc/fetch_quranenc_audio.py` and
`pipeline/quranenc/fetch_everyayah_audio.py`. Neither wires into
`config/sources.yaml` or the R2 publish scripts yet — they are pilot/local
downloaders only.

This app already has one shipped Alafasy Arabic recitation with a stream+cache
pattern (see `roadmap-audio-recitation` in project memory / the audio
recitation feature under `lib/features/reader/`) — translation audio should
reuse that pattern, not invent a second caching mechanism.

## Decisions locked in (2026-08-08)

1. **Scope**: Detailed mode only. Reading mode stays Arabic-recitation-only,
   same as the existing feature and the Urdu POC.
2. **Audio is a separate opt-in per translation, independent of the text
   toggle.** Enabling "Sahih International" text in the Translations sheet
   does **not** automatically start pulling its audio. Each audio-backed
   translation gets its own toggle (e.g. a speaker icon in the translation
   row) so enabling text doesn't silently commit the user to new data usage.
   The toggle means **"include this translation audio after Arabic when
   playback reaches an ayah"**, not "download the whole audio set now" — Sahih
   International alone is still roughly 1-1.5 GB. V1 should stream + cache
   ayah-by-ayah, with explicit full-pack download/cache management treated as a
   later UX.
3. **Applies to both single-ayah tap-to-play and continuous full-surah
   playback**, but with a dedicated setting to disable translation audio
   specifically during continuous playback (so a user can keep per-verse
   study mode fully chained while continuous listening stays fast).
4. **Fixed priority order**, not display/list order: Sahih International,
   then Rowwad Center, then any further audio-backed translation added later.
   This is independent of the text reader's language display order (Urdu →
   Hindi → English) — translation-audio order is its own list, since it's
   gated on which editions actually have audio, not which languages exist.
5. **Missing-asset handling**: per-ayah, not per-edition. If a translation's
   audio toggle is on but the specific ayah's file is missing (e.g. a future
   edition with partial coverage, or a corrupt/failed download), skip just
   that segment silently and continue the chain — do not disable the whole
   toggle or stop playback. (Extends the Urdu POC's stricter "stop on missing"
   default — POC scope was 7 verses with 100% verified coverage, so any
   failure there was necessarily a bug; production scope spans thousands of
   files across multiple editions where an isolated gap is an expected,
   non-fatal event.)
6. **Repeat-one repeats the whole ayah chain, not the current audio segment.**
   The existing player maps repeat-one to `just_audio`'s `LoopMode.one`, which
   is correct for a single Arabic file but may loop only the active segment in
   a `ConcatenatingAudioSource`. Translation-audio repeat must be implemented
   at the ayah-chain level: Arabic + enabled translation segments replay
   together.

## Architecture

Following this repo's Clean Architecture rule (`domain/` pure Dart, `data/`,
`presentation/`, no cross-feature imports) — all of this lives inside
`lib/features/reader/`, alongside the existing recitation code, not as a new
top-level feature.

### Domain layer additions

```dart
// lib/features/reader/domain/entities/translation_audio_resource.dart
class TranslationAudioResource {
  const TranslationAudioResource({
    required this.slug,            // e.g. "en-sahih-international-audio"
    required this.textResourceSlug, // e.g. "en-sahih-international" — FK-ish link
    required this.languageCode,
    required this.narratorName,
    required this.priority,        // fixed chain order, lower = earlier
    required this.baseUrl,
    required this.namingScheme,    // "SSSAAA" for both sources seen so far
  });
}
```

```dart
// lib/features/reader/domain/entities/ayah_playback_queue.dart
enum AudioSegmentKind { recitation, translationAudio }

class AyahAudioSegment {
  const AyahAudioSegment({
    required this.kind,
    required this.uri,          // resolved cache-or-remote URI
    required this.cacheKey,     // stable namespace/path, used by stream+cache
    this.translationSlug,       // null for recitation
  });
}

// Built once per ayah, consumed by the player cubit.
List<AyahAudioSegment> buildAyahQueue({
  required Ayah ayah,
  required ReciterSelection reciter,
  // Already priority-sorted.
  required List<TranslationAudioResource> enabledTranslationAudios,
  required AudioAvailabilityChecker availability, // per-ayah asset check
});
```

`buildAyahQueue` is the single chokepoint analogous to `translationResources()`
in `core/database/app_database.dart` for text — a pure function, easily unit
tested without Flutter/audio-plugin dependencies, that turns "what's enabled"
+ "what's actually available for this ayah" into an ordered segment list.

Keep the numbering rules explicit and unit-tested. Today's Arabic recitation
uses the app's global ayah id (`1..6236`), but everyayah/QuranEnc translation
audio uses `SSSAAA` filenames. Add pure helpers alongside the queue builder:

```dart
String ayahAudioKey({required int surah, required int ayah}); // 2:1 -> 002001
Uri translationAudioUri(TranslationAudioResource resource, Ayah ayah);
String translationAudioCacheKey(TranslationAudioResource resource, Ayah ayah);
```

These helpers are canaries: Fatiha 1:1 must map to `001001`, Baqarah 2:1 to
`002001`, and the Arabic recitation path must continue to use global id `8` for
Baqarah 2:1.

### Data layer additions

- `AudioResourcesDao` (or extend whatever DAO backs the existing recitation
  resource) — reads translation-audio resource metadata (slug, priority,
  base URL, narrator) from a new `translation_audio_resources` table,
  mirroring `resources`/`translations` shape but for audio:

  ```sql
  CREATE TABLE IF NOT EXISTS translation_audio_resources (
      id                  INTEGER PRIMARY KEY,
      slug                TEXT NOT NULL UNIQUE,
      text_resource_slug  TEXT NOT NULL,   -- links to resources.slug
      language_code       TEXT NOT NULL,
      narrator_name       TEXT,
      priority            INTEGER NOT NULL,
      base_url            TEXT NOT NULL,
      naming_scheme       TEXT NOT NULL DEFAULT 'SSSAAA',
      file_extension      TEXT NOT NULL DEFAULT 'mp3',
      total_ayahs         INTEGER NOT NULL DEFAULT 6236,
      license             TEXT,
      source_url          TEXT,
      enabled             INTEGER NOT NULL DEFAULT 1
  );
  ```

  This table is metadata-only (URLs/config), same "lean, data-driven, no
  hardcoded per-language UI" principle already used for `resources` — adding
  a translation-audio edition later is a data change, not a code change,
  matching how `TRANSLATIONS-ROADMAP.md`/`sources.yaml` already work for text.
  Long-term, prefer sourcing this metadata from a remote audio catalogue
  (cached locally) rather than only from bundled `quran.db`, so adding/fixing an
  audio resource does not require an app-store release. A bundled table can
  seed the app, but the CDN catalogue should be the source of truth once the
  feature leaves POC.

- Per-ayah availability: rather than a `6236`-row-per-edition tracking table
  (expensive to maintain and sync), prefer a **cheap lookup against a loaded
  availability manifest**, not a network HEAD/request at playback time. The
  same `files.json` QuranEnc already publishes per edition is a ready-made
  per-ayah completeness manifest; mirror/normalize it into the
  downloadable-editions `catalogue.json`-style metadata already used for text
  editions (see `alquran-data`'s `build_editions.py`) rather than inventing a
  new format. At runtime, load it once into a `Set<String>`/bitset of available
  `SSSAAA` keys so `buildAyahQueue` stays fast and deterministic.
- Reuse the existing recitation cache directory strategy and eviction policy;
  key translation-audio cache entries by `<translationAudioSlug>/<SSSAAA>.mp3`
  so they don't collide with reciter cache entries keyed by
  `<reciterSlug>/<SSSAAA>.mp3`.

### Presentation layer additions

- Extend the existing playback cubit (wherever single-ayah/continuous
  recitation state lives today) so its "now playing" unit becomes the
  per-ayah **segment queue** from `buildAyahQueue`, not a single clip URI.
  Advancing within an ayah walks the queue; advancing to the next ayah
  rebuilds the queue for that ayah.
- The current `AyahRecitationPlayer.play(int ayahId)` is a single-clip
  interface over one `LockCachingAudioSource`. Do not hide queue construction
  inside the plugin-backed player. Prefer a new player contract such as
  `play(AyahPlaybackPlan plan)` where the cubit/domain layer passes an ordered
  Arabic+translation segment list. The player should only translate that plan
  into `AudioSource`s, stream/cache files, and emit segment/ayah progress.
- Translations sheet (the bottom sheet shown in the screenshot from this
  conversation) gains a per-row audio toggle for any translation that has a
  `TranslationAudioResource` — most translations (Urdu Junagarhi, Hindi,
  etc.) simply have no toggle since no audio resource exists for them yet.
  UI copy must make the behavior clear, e.g. "Play audio after Arabic" or
  "Include translation audio", not merely a standalone speaker icon that could
  be mistaken for a preview button.
- A new Settings/Reader-options entry: "Translation audio during continuous
  playback" (on/off), defaulting to **on** per decision #3, but overridable.
- "Now playing" indicator should track which segment is active (Arabic vs.
  which translation) so the corresponding text block can be highlighted —
  nice-to-have, not required for v1, flagged here so the UI leaves room for
  it rather than hardcoding a single "ayah playing" highlight.

## Phase 2 status (2026-08-08)

Built and verified on-device (iOS simulator): Arabic → Sahih International
chains correctly through all 7 Al-Fatihah verses, flag is on.

**Updates since the initial POC (same day):**
- **Repeat-one now replays the full chain (decision #6 implemented).**
  `AyahAudioCubit._syncLoopMode` keeps the player's native `LoopMode.one` for
  the common case (no translation audio in play), but switches to a
  cubit-level replay — Arabic completes normally, the translation clip plays,
  then the SAME ayah replays — whenever translation audio is enabled for an
  in-scope (Fatiha) verse, since `just_audio`'s native loop never emits
  `completed` and would otherwise skip the translation segment forever.
- **Autoplay no longer rolls into the next surah at all** (a related fix, not
  originally in scope for this doc): the reader used to auto-advance
  section-to-section on its own (`_autoAdvanceSection`/`onSequenceEnd`),
  continuing Arabic recitation continuously across surah boundaries. That
  wiring was removed — a section's last verse now simply stops playback.
  Affects Arabic-only recitation too, not just this POC's chain.
- **The Settings-sheet toggle is gone.** Translation audio is now controlled
  per-verse from a headphones icon in the ayah row's toolbar (next to the
  play button — `AppIcons.translationAudio`,
  `WidgetKeys.ayahTranslationAudioToggle(ayahId)`), one tap, no Settings
  detour. Still session-only (resets on reader reopen), still forwards to the
  same `AyahAudioCubit.setTranslationAudioEnabled` flag.
- **The icon only shows when it can do something:** gated on
  `FeatureFlags.translationAudioFatihaPoc`, the verse being in Fatiha's POC
  scope (`isFatihaPocAyah`), AND at least one of the reader's *currently shown*
  translations actually having an audio track
  (`hasAnyTranslationAudio` / `translationAudioResourceSlugs` in
  `core/audio/translation_audio_source.dart` — POC: just
  `en-sahih-international`). A reader showing only Urdu/Hindi never sees the
  icon. This is the mapping Phase 4 extends by adding more slugs to that set —
  no new UI code.

**Updates since Phase 1.5 (2026-08-08, same day):**
- **R2 upload done, bundled assets removed.** The 7 Al-Fatihah clips are live
  at `https://audio.alquranreader.com/translation-audio/en-sahih-international/
  <SSSAAA>.mp3` (bucket `al-quran-audio`, no `catalogue.json` — plain files,
  same shape as `recitation/`). `TranslationAudioPlayer`/
  `JustAudioTranslationPlayer` now stream + cache via `LockCachingAudioSource`
  (mirrors `JustAudioRecitationPlayer`) instead of `setAsset`ing a bundled
  file; `assets/audio/poc/` is deleted and no longer in `pubspec.yaml`. A
  network/cache failure is swallowed silently (decision #5) rather than
  throwing, since this is now a real network fetch instead of a guaranteed-
  present bundled asset.

**Deliberately NOT done yet, by design, not oversight:**
- No persistence for the toggle (session-only, resets on reader reopen).
- No "now playing" segment highlight (Arabic vs. translation).
- No continuous-playback master on/off switch (decision #3) — only
  single-ayah tap-to-play chains right now; continuous mode is untested.
- Full-Quran Sahih International audio, Rowwad, and everything past
  Al-Fatihah (Phase 3/4) untouched.

## Rollout phases

1. **Phase 0 (done)**: source discovery + pilot fetch for Sahih International
   audio in `alquran-data` (this doc's companion work). No app changes yet.
2. **Phase 1 — data pipeline, narrowed to Al-Fatihah's 7 files (done,
   2026-08-08)**: published the 7 already-fetched Al-Fatihah Sahih
   International files (`sources/audio/sahih-international/001001.mp3`..
   `001007.mp3` in `alquran-data`, byte-identical to today's bundled app
   assets) to R2 — bucket `al-quran-audio` (same bucket `recitation/` already
   lives in), under a **sibling** prefix `translation-audio/en-sahih-international/`,
   keyed `SSSAAA.mp3` (translation-audio's own numbering, NOT the global
   1..6236 id `recitation/` uses). No `catalogue.json` / content-addressed
   filenames — audio follows the simpler `recitation/` precedent (plain
   files, the app builds URLs directly), not the text-editions packaging
   pipeline. Verified live (all 7 URLs HTTP 200, byte-exact `Content-Length`).
   Full step-by-step commands + verification, written to run standalone (no
   context from this doc needed):
   `../alquran-data/docs/translation-audio-r2-publish-plan.md`.
   **Full-Quran Sahih International (6236 files) was explicitly NOT part of
   this step** — that fetch was still in progress in `alquran-data`
   (2,818/6236 as of 2026-08-08) and gets its own publish pass, now underway:
   `../alquran-data/docs/translation-audio-full-quran-plan.md` (folded into
   Phase 3 below). Licensing exit gate already cleared (owner, 2026-08-08 —
   see "Open questions" below), was not a blocker for this step.
3. **Phase 1.5 — app-side switch off the bundled asset (done, 2026-08-08)**:
   stopped bundling `assets/audio/poc/en-sahih-international/*.mp3` in the
   app; streams + caches from R2 instead — the SAME pattern
   `core/audio/recitation_source.dart`
   / `JustAudioRecitationPlayer` already use for Arabic (`LockCachingAudioSource`,
   first play streams-and-caches to a deterministic on-disk path, replays are
   offline). Concretely, in this repo:
   - `core/audio/translation_audio_source.dart`: add
     `translationAudioUrl({surah, ayah})` (mirrors `alafasyUrl`, points at
     `https://audio.alquranreader.com/translation-audio/en-sahih-international/<SSSAAA>.mp3`)
     and `translationAudioCacheRelativePath({surah, ayah})` (mirrors
     `recitationCacheRelativePath`, e.g.
     `translation-audio/en-sahih-international/<SSSAAA>.mp3` under the app's
     cache dir — deliberately namespaced so it can never collide with a
     reciter's cache entries). Delete `sahihInternationalAssetPath` once
     nothing references it — no local-asset fallback is planned.
   - `core/audio/translation_audio_player.dart`: replace
     `JustAudioTranslationPlayer`'s `setAsset`-based one-shot player with a
     `LockCachingAudioSource`-backed one (same shape as
     `JustAudioRecitationPlayer.play`), so `TranslationAudioPlayer`'s
     interface method takes a resolved URI + cache path (or a `surah`/`ayah`
     pair it resolves internally) instead of a bundled asset path.
   - `AyahAudioCubit._advanceAfterCompletion`: swap the
     `_translationPlayer.playAsset(sahihInternationalAssetPath(...))` call for
     the new URL-based one.
   - `pubspec.yaml`: remove the
     `assets/audio/poc/en-sahih-international/` asset entry; delete the 7
     bundled files (they only ever existed to avoid a CDN dependency during
     the POC — see `docs/dual-audio-urdu-poc-plan.md` Track 2 — that reason
     goes away once R2 is live).
   - Tests: `test/core/audio/translation_audio_source_test.dart` gets a
     numbering canary for the new URL helper (mirrors
     `test/core/audio/recitation_source_test.dart`); the
     `_FakeTranslationPlayer` in `test/features/reader/ayah_audio_cubit_test.dart`
     updates its `playAsset` fake to the new interface shape.
   - Manual verification: on-device, confirm all 7 Fatiha verses still chain
     correctly with the SAME toggle UX as before — this step must be
     behaviorally invisible to the reader, only the audio source changes.
4. **Phase 2 (done)**: the app POC shipped against bundled assets — see
   "Phase 2 status" above. Phase 1.5 swaps its audio source only; the
   queue-builder/chaining design it proved (and the per-verse toggle,
   chained repeat-one, etc. built on top of it since) is unaffected.
5. **Phase 3 — full rollout**: full-Quran Sahih International audio
   (fetch-then-publish, same shape as Phase 1 but for all 6236 files —
   data-repo half in progress: `../alquran-data/docs/translation-audio-full-quran-plan.md`),
   then on the app side: widen `isFatihaPocAyah`'s scope gate past Fatiha,
   per-row audio toggle in the Translations sheet, continuous-playback
   setting, download/cache management UI, error-handling per
   `docs/error-handling-runbook.md`.
6. **Phase 4 — Rowwad and beyond**: once `english_rwwad` is compressed
   (owner's stated follow-up) and/or other QuranEnc translation-audio
   editions are chosen, add them as additional `translation_audio_resources`
   rows — no new app code, same as adding a text translation today.

## Phase 3 — full-Quran rollout plan (drafted 2026-08-08)

Trigger: the full 6236-file Sahih International set is now live on R2 at
`translation-audio/en-sahih-international/<SSSAAA>.mp3` (confirmed via the R2
console — `001001.mp3`/`001002.mp3`/`001003.mp3` etc. present under
`al-quran-audio/translation-audio/en-sahih-international/`), same layout the
Phase 1.5 code already targets. This phase is app-only — no further data-repo
work is required to widen scope past Al-Fatihah.

### 3.1 Verification before flipping scope

- [ ] Confirm object count in the R2 prefix is 6236 (not a partial sync) —
  `rclone`/`aws s3 ls --recursive | wc -l` style count against the bucket, or
  the R2 dashboard's object count for the prefix.
- [ ] Spot-check the audit set from the original POC's exit criteria: last 10
  surahs (114 down to 105), Ayat al-Kursi (2:255), a few long Baqarah verses —
  confirm each file is non-empty and plays.
- [ ] Confirm no `catalogue.json`/manifest is needed for v1: since every ayah
  is now present, `buildAyahQueue`-style per-ayah availability checking can
  stay a no-op (assume present, fail soft on a 404) rather than requiring a
  loaded manifest — simpler than the "Per-ayah availability manifest format"
  open question below, and matches decision #5 (skip only the missing
  segment, don't block the toggle).

### 3.2 Code changes

All changes are narrow — the Phase 2 architecture (queue chaining, chained
repeat-one, cache-key namespacing) is already scope-agnostic; only the
Fatiha-only gate needs to widen.

1. **`core/audio/translation_audio_source.dart`**
   - Replace `isFatihaPocAyah` with a full-Quran scope check (or delete it
     entirely — once every ayah has audio, the gate collapses to "surah/ayah
     is a valid Qur'an reference", which the reader already guarantees before
     this code ever runs). Simplest: delete the scope check altogether and
     let `hasAnyTranslationAudio` (resource-slug gating) be the only gate —
     an ayah either has the Sahih International text shown or it doesn't;
     if shown, its audio is now always available.
   - Keep `translationAudioResourceSlugs` as the extension point for Phase 4
     (Rowwad, etc.) — no change needed there.

2. **`features/reader/presentation/cubit/ayah_audio_cubit.dart`**
   - Delete `_inFatihaPocScope` (and its Fatiha-specific global-id-equals-
     ayah-number comment/shortcut) — `_advanceAfterCompletion` and
     `_chainedRepeatOneActive` gate purely on `_translationAudioEnabled` plus
     the ayah's actual `surah`/`ayahNumber` (already available via the
     `Ayah` passed through from the reader, not the global id hack the POC
     used because Fatiha made global-id and ayah-number coincide). This means
     `_advanceAfterCompletion` needs the completed verse's real
     `surah`/`ayahNumber`, not just its global id — thread that through from
     wherever `play(ayahId)` already resolves an `Ayah` (the reader/repository
     layer), since `_player.play` currently takes only a global id.
   - Missing-asset handling: on a `TranslationAudioPlayer.play` failure
     (network/404), swallow and continue the chain per decision #5 — confirm
     `JustAudioTranslationPlayer` already does this (Phase 1.5 notes say yes,
     "swallowed silently") and add a regression test for it now that misses
     are an expected, non-Fatiha-only case.

3. **`core/feature_flags.dart`**
   - Rename `translationAudioFatihaPoc` → `translationAudio` (or similar),
     update its doc comment to drop "Al-Fatihah"/"bundled"/"7 verses"
     language now stale post-Phase-1.5. Keep it a flag (not delete) — still
     useful as an emergency kill switch before the feature is fully proven at
     full scope.

4. **`features/reader/presentation/pages/reader_page.dart`**
   - The two call sites gated on `isFatihaPocAyah(...)` (lines ~1560, in the
     headphones-icon visibility check) drop that clause — visibility becomes
     purely `FeatureFlags.translationAudio && hasAnyTranslationAudio(shown)`.
   - `_syncTranslationAudioAvailability` (line 916) — same flag rename, no
     other logic change (it already only depends on `hasAnyTranslationAudio`,
     not the Fatiha gate).

5. **Continuous-playback setting (plan decision #3, still open)**: add the
   "Translation audio during continuous playback" toggle referenced in the
   original architecture section — default **on**. Needed now because
   continuous full-surah playback becomes a real, common path once scope
   isn't limited to 7 verses (in the POC, nobody would "continuously play"
   past Fatiha into silence). Lives in Settings/reader-options alongside
   speed/repeat, read by `AyahAudioCubit` the same way `_speed` is.

6. **Per-row toggle in the Translations sheet** (plan's "Presentation layer
   additions", still open): today the only way to enable translation audio is
   the per-verse headphones icon in the ayah toolbar. That stays as the
   primary control (works fine at full scope), but the Translations sheet
   should surface *which* shown translations have an audio track available
   (small icon/badge next to "Sahih International") so the reader
   understands why the headphones icon appeared — not a second toggle,
   just discoverability. Optional for the first full-scope release; can slip
   to a fast-follow if time-boxed.

### 3.3 Tests

- `translation_audio_source_test.dart`: delete/replace the `isFatihaPocAyah`
  canary with tests confirming the URL/cache-path helpers work for ayahs
  across multiple surahs (e.g. 2:255, 114:6), not just Fatiha's 1..7.
- `ayah_audio_cubit_test.dart`: extend the existing chain/repeat-one fakes to
  cover a non-Fatiha verse (e.g. surah 2), and add a case where the fake
  translation player throws/errors mid-chain — assert playback continues to
  the next verse rather than stalling (decision #5's missing-asset handling,
  now testable since it's a real code path, not a hypothetical POC gap).
- Manual device pass: pick 3-4 verses spread across different surahs
  (not just Fatiha) in both single-verse and continuous playback, confirm the
  chain (and chained repeat-one) still works, and confirm the flag/off state
  is still byte-identical to Arabic-only playback.

### 3.4 Rollout sequencing

1. Land 3.1's verification (no code change) — confirms R2 is actually ready.
2. Land 3.2 items 1-4 (scope widening) + 3.3 tests, flag stays **on** in a
   build the owner tests on-device across several non-Fatiha surahs.
3. Land 3.2 item 5 (continuous-playback setting) as a fast-follow once the
   core widening is verified stable.
4. Item 6 (Translations-sheet discoverability) and cache/download management
   UI (explicitly deferred in the original plan) stay backlog items — track
   in `docs/quality-backlog.md` per the existing convention, not blockers for
   this rollout.
5. Update this doc's Phase 2/1.5 status header and the `docs/quality-backlog.md`
   entry (if any) once 3.2 ships, so "Fatiha POC" language doesn't linger
   stale in the codebase the way `isFatihaPocAyah`'s name would otherwise
   imply forever.

## Open questions

- **Compression target for `english_rwwad`**: what bitrate/format reduction
  gets it competitive with everyayah's ~150 KB/ayah average (from QuranEnc's
  ~795 KB/ayah)? Needs a pipeline step (likely re-encode via ffmpeg at a lower
  bitrate) before Phase 4 for that edition — worth scoping as its own small
  task once Sahih International ships and the pattern is proven.
- ~~**R2 prefix naming**~~ — **RESOLVED 2026-08-08:** `translation-audio/<slug>/`
  inside the existing `al-quran-audio` bucket, sibling to `recitation/`.
  Locked in for the Phase 1 Al-Fatihah publish
  (`../alquran-data/docs/translation-audio-r2-publish-plan.md`).
- **Per-ayah availability manifest format**: reuse QuranEnc's `files.json`
  shape directly, or normalize it into this repo's existing
  `catalogue.json` shape for consistency with text editions? Leaning
  normalize, to keep one manifest format across the whole app, but not
  decided. Doesn't block the Al-Fatihah pilot (7/7 files, no missing-asset
  case to handle yet) — matters once Phase 3 covers the full 6236.
- **Now-playing highlight**: v1 nice-to-have or explicit backlog item for
  `docs/quality-backlog.md`?
- ~~**Repeat/loop mode interaction**~~ — **RESOLVED 2026-08-08:** implemented
  as "full chain" (`AyahAudioCubit._syncLoopMode`/`_chainedRepeatOneActive`) —
  repeat-one on a chained verse replays Arabic + translation together, not
  just Arabic. See "Phase 2 status" above.
- ~~**License confirmation for audio specifically**~~ — **RESOLVED 2026-08-08
  (owner):** owner has personally checked the legal position and confirmed
  everyayah.com's Sahih International/Ibrahim Walk recording is free to
  distribute for non-commercial use, which covers this app. No longer a
  blocker for Phase 1 publishing. (QuranEnc audio terms specifically remain
  unconfirmed, but that only matters again at Phase 4/Rowwad.)
