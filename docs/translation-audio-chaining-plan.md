# Translation Audio Chaining Plan (Detailed Mode)

Status: **Phase 2 (Al-Fatihah POC) built and verified on-device 2026-08-08**
(iOS simulator — Arabic + Sahih International chained correctly through all 7
verses). `FeatureFlags.translationAudioFatihaPoc = true`. Builds on the
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
chains correctly through all 7 Al-Fatihah verses, toggle in Reader Settings
(Detailed mode) works, flag is on.

**Deliberately NOT done yet, by design, not oversight:**
- **No R2 upload.** The 7 clips are bundled app assets
  (`assets/audio/poc/en-sahih-international/*.mp3`, ~948 KB total, registered
  in `pubspec.yaml`) — same choice the Urdu POC made for the same reason
  (avoid CDN uncertainty during an app-level POC). **Phase 1 (the data
  pipeline: packaging + `catalogue.json` + `al-quran-audio` R2 publish) has
  not been built at all** — only the local pilot fetch in `alquran-data`
  happened (see "Source data confirmed" above). Don't expect anything on R2
  for translation audio yet; that's tomorrow's work if/when this expands past
  Al-Fatihah.
- No persistence for the toggle (session-only, resets on reader reopen).
- No "now playing" segment highlight (Arabic vs. translation).
- No continuous-playback master on/off switch (decision #3) — only
  single-ayah tap-to-play chains right now; continuous mode is untested.
- Repeat-one loops the Arabic segment only, not the full chain (decision #6
  not yet implemented).
- Full-Quran Sahih International audio, Rowwad, and everything past
  Al-Fatihah (Phase 3/4) untouched.

## Rollout phases

1. **Phase 0 (done)**: source discovery + pilot fetch for Sahih International
   audio in `alquran-data` (this doc's companion work). No app changes yet.
2. **Phase 1 — data pipeline**: build the `alquran-data` side properly —
   `translation_audio_resources` equivalent in the pipeline's schema, a
   `build_editions`-style packaging step for audio (content-addressed,
   `catalogue.json`-style manifest, R2 publish under a new prefix in the
   existing `al-quran-audio` bucket — **not** the `recitation/` prefix the
   owner pointed at, since this is conceptually a sibling, e.g.
   `translation-audio/<slug>/`). Publish Sahih International only.
   **Exit gate:** audio licensing/attribution terms are confirmed for the
   specific Sahih International/Ibrahim Walk files before any public R2/app
   usage. Do not treat this as a soft follow-up.
3. **Phase 2 — app POC**: extend the existing Urdu POC's queue-builder
   concept (`DualAudioSegment`/`ConcatenatingAudioSource` pattern already
   proven there) to the priority-ordered, N-translation `buildAyahQueue`
   design above. Ship behind a feature flag, Detailed mode, one surah first
   (reuse Al-Fatihah as the smoke test, matching the POC precedent). Keep the
   POC deliberately narrow: Sahih International only, stream+cache per ayah,
   no full-pack download UI, no Rowwad, and no extra language-selection UX.
4. **Phase 3 — full rollout**: full-Quran Sahih International audio, per-row
   audio toggle in the Translations sheet, continuous-playback setting,
   download/cache management UI, error-handling per
   `docs/error-handling-runbook.md`.
5. **Phase 4 — Rowwad and beyond**: once `english_rwwad` is compressed
   (owner's stated follow-up) and/or other QuranEnc translation-audio
   editions are chosen, add them as additional `translation_audio_resources`
   rows — no new app code, same as adding a text translation today.

## Open questions

- **Compression target for `english_rwwad`**: what bitrate/format reduction
  gets it competitive with everyayah's ~150 KB/ayah average (from QuranEnc's
  ~795 KB/ayah)? Needs a pipeline step (likely re-encode via ffmpeg at a lower
  bitrate) before Phase 4 for that edition — worth scoping as its own small
  task once Sahih International ships and the pattern is proven.
- **R2 prefix naming**: proposed `translation-audio/<slug>/` inside the
  existing `al-quran-audio` bucket, sibling to `recitation/` — confirm before
  Phase 1 publishing, since prefixes are effectively permanent once clients
  reference them.
- **Per-ayah availability manifest format**: reuse QuranEnc's `files.json`
  shape directly, or normalize it into this repo's existing
  `catalogue.json` shape for consistency with text editions? Leaning
  normalize, to keep one manifest format across the whole app, but not
  decided.
- **Now-playing highlight**: v1 nice-to-have or explicit backlog item for
  `docs/quality-backlog.md`?
- **Repeat/loop mode interaction**: if a user loops a single ayah (existing
  recitation feature), does the loop replay the full chain (Arabic +
  translations) or just Arabic? Leaning "full chain," since the loop target
  is "this ayah," not "this ayah's Arabic," but not yet confirmed with the
  owner.
- ~~**License confirmation for audio specifically**~~ — **RESOLVED 2026-08-08
  (owner):** owner has personally checked the legal position and confirmed
  everyayah.com's Sahih International/Ibrahim Walk recording is free to
  distribute for non-commercial use, which covers this app. No longer a
  blocker for Phase 1 publishing. (QuranEnc audio terms specifically remain
  unconfirmed, but that only matters again at Phase 4/Rowwad.)
