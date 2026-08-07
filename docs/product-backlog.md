# Product backlog — features (shipped + missing)

Feature-level status across the Al Quran ecosystem (this app, `../alquran-data`,
`../al-quran-web`), from a reader's perspective. Distinct from
`quality-backlog.md`, which tracks bugs/UX rough edges in features that already
exist. Update this file as features ship or scope decisions change; don't let
it drift from `FeatureFlags` / the actual code.

Performance is an active pre-release quality track, backed by physical-device
profile measurements rather than simulator impressions. See
[`performance-roadmap.md`](performance-roadmap.md) for the baseline, budgets,
priorities, and release gate.

## Shipped

- **Reading + Detailed viewport modes** — Arabic-only vs Arabic + Urdu/Hindi/English, pinch-to-zoom (20–48pt), +/- font buttons.
- **Surah navigation** — full list of 114, search (mirrors web quickMatch).
- **Audio recitation** — tap-a-verse + continuous full-surah autoplay (cross-surah), Alafasy, self-hosted CDN stream+cache. Foreground-only (see below).
- **IndoPak script** — Noorehuda font, authentic Quran.com `text_indopak`, flag ON.
- **Multiple translations, multi-language** — Urdu (Junagarhi, default), Hindi (Suhel Farooq Khan/Nadwi), English (Hilali & Khan) bundled in the current seed; the edition model (data repo, 2026-07-28) supports several editions per language and on-demand downloads via a Translations screen reading a CDN catalogue. A translation slug must appear in exactly one visible bucket: bundled/on-device, installed/on-device, or available for download — never both bundled and downloadable.
- **Continue reading** — resumes the exact verse, in the viewport you left off in; the open stamp waits for a dwell so a glance can't overwrite a deep position.
- **Light of Day** — time-adaptive theming (pillar 1 of 3; shipped as the "dark mode" answer instead of a literal toggle).
- **Prayer times sheet** — Karachi method + Shafi Asr (hard-wired, no other madhab options), Hijri date shown.
- **Reader virtualization** — page-chunked lazy list, ~17-31ms open time.
- **Bookmarks** — ayah-level, multiple, with a bookmarks screen (`AyahBookmarkRepository`, verse address only — no notes/tags yet).
- **Sunnah reminders** — local notifications for Al-Kahf (Friday), White Days, Ashura, Arafah, Dhul Hijjah; the Al-Kahf one routes into the reader and resumes where you left off.
- **Salat notifications** — local notifications at each of the 5 daily prayer times (2026-08-04, `FeatureFlags.prayerTimeNotifications`); tapping one opens the Prayer Times sheet. Both reminder types now live on one unified "Reminders" screen (uniform toggle + info popover per row), reachable from the Home overflow.
- **Tafsir** — **SHIPPED 2026-08-06/07** (was Roadmap #1 / "Missing" below — both now stale). Per-ayah tafsir surfaced in the Detailed view via a bottom sheet, plus a Translations-style manager screen (browse a CDN catalogue, download/remove editions, catalogue visibility flags). No `FeatureFlags` gate — ships unconditionally. Data side: a `tafsir` resource type + table parallel to `translations`, ayah-range aware. See `lib/features/tafsir/`.
- **Soft app-update reminder** — a dismissible Home banner + a Settings "Check for Updates" row read a shared `AppUpdateCubit`, backed by a small remote JSON config (`FeatureFlags.softUpdateReminder`). Manual checks always resolve to an in-app result (available / up to date / couldn't check); required updates (via `minimumSupportedVersion`) can't be dismissed; "Later" only suppresses the exact version dismissed. See `lib/features/app_update/` and `docs/error-handling-runbook.md`.

## Built but flagged OFF for v1

- **Juz / Hizb / Ruku / Page "Jump to" navigation** — fully built, DB carries all indices (page 1–604, juz 1–30, hizb 1–60, rub 1–240, ruku 1–558, 15 sajdas). Gated behind `FeatureFlags.advancedNavigation`, OFF by owner decision (v1 = Surah-only, reading-first home). **Cheapest re-enable in this whole list — no new work, just flip the flag** when ready to bring it back.
- **Home-screen prayer widgets** — Android (`PrayerWidgetProvider`, `PrayerScheduleWidgetProvider`) and iOS WidgetKit targets are BUILT and committed, gated behind `FeatureFlags.homeScreenWidgets` (OFF for v1: the app never feeds them). Note the native targets still ship in the build — to keep them out of the OS widget gallery entirely, drop the iOS extension target and the Android `<receiver>` registrations.

## Missing — no ingestion/implementation started anywhere in the 3 repos

- **Word-by-word translation** — Arabic word-by-word text is already used internally (QUL `quran-script/312` powers ayah reconstruction), but no per-word *translation* is ingested or rendered. Needs its own QUL source + schema + UI (word-tap popovers).
- **Tajweed (color-coded pronunciation rules)** — → **Roadmap #8**. Not started; needs a tajweed-annotated Arabic source (QUL has tajweed-rule Uthmani exports) and rendering support (likely a different font/markup approach than the current KFGQPC text).
- **Exact-Mushaf page rendering** (line-for-line matching the print Mushaf, not flowing text) — not started. Current reader flows paragraphs; page number is tracked but line-breaks aren't reproduced.
- **Full-text / verse-text search** — not started in the app. Web has surah-*name* search only (quickMatch), not verse-content search.
- **Bookmark notes / naming** — ayah bookmarks themselves shipped (see above); naming or annotating them has not. The web backlog's local-storage/privacy decision still applies if these ever sync.

## Deferred to a later release (explicit owner decisions, not forgotten)

- **Lock-screen / background audio** — see `quality-backlog.md` #11; foreground-only today.
- **Tablet-specific layout** — no tablet UI; phone layout stretched. Deferred to release-after-next.
- **Hifz (memorization) page mode** — optional page-wise mode without zoom/pan, roadmap item, not started.
- **iOS Location Services fallback** — later UX pass for prayer times when global Location Services are off on iOS. Android now opens system Location settings from the Home location icon; iOS needs a platform-specific check/flow (likely app/system Settings affordance plus a future "Choose city" fallback). Do not try to silently enable Location Services; both platforms require user action.

## Roadmap — owner's next-version list (2026-08-01)

Ordered as the owner raised them, not by priority. Each notes where the work
actually lands, since most of these start in `../alquran-data`, not here.

1. ~~**Tafsir in the Detailed view**~~ — **SHIPPED 2026-08-06/07** (see Shipped
   above). Per-ayah tafsir sheet + a downloadable-editions manager, ayah-range
   schema. Two editions ingested so far (Tafsir Ibn Kathir, English abridged +
   Urdu — `../alquran-data/config/tafsir.yaml`); more editions (and picking the
   right creed/audience per language) is now data-side work, tracked with the
   rest of translation editions in `../alquran-data/TRANSLATIONS-ROADMAP.md`,
   not a separate app roadmap item. Licensing on both is still marked "VERIFY"
   — part of the pre-release licensing gate.
2. **Downloadable script / Mushaf text packs** — **P1**. Add separately
   downloadable Arabic text editions so the reader can switch between Classic
   Madani Mushaf, Naskh/IndoPak, and the current Mushaf Unicode text. Model this
   like Quran.com native apps / Al Quran (word by word): each script pack should
   be independently installable, removable, and selectable in reader settings,
   rather than all scripts being bundled forever. This likely belongs beside the
   existing downloadable-editions pipeline, but as Arabic script/text resources,
   not translation resources. Preserve stable identities by slug, never DB ids;
   verify each artifact by sha256 before install; and keep line/page fidelity as
   an explicit acceptance gate for the Classic Madani pack.

   **Reference apps — take a different thing from each** (owner, 2026-08-02):

   - **KFGQPC "Quran Hafs"** (`sa.QuranComplex.QuranHafs`, King Fahd Complex —
     the publisher of the printed Madani Mushaf) — the *fidelity* benchmark.
     What to club in: the page **is** the unit, not a verse list — one screen =
     one printed page, 15 lines, horizontal page-turn, no vertical scroll, and
     lines justified edge-to-edge exactly as printed — built as **per-page
     fonts over one shared frame image** — plus **pinch-zoom**, which neither
     Quran.com nor Al Quran (word by word) offers (a product omission on their
     side, not a technical limit: vector glyphs scale for free).
     Verses are tapped *on the page* to open actions, so the reading surface
     stays undisturbed. Also the reason to prefer this pack's text: it is the
     publisher's own, so provenance for "Classic Madani" is authoritative
     rather than reconstructed. Cost: ~25–45 MB pack, 604 lazily-loaded font
     families to keep off the heap, and a licensing check on the QPC fonts +
     frame artwork (see the licensing gate).
   - **Al Quran (Greentech), Madani Mushaf 1440** — proves page fidelity and
     **selectable/tappable verses** coexist: tap a verse → translations (our
     Detailed-view content) + actions. That is the interaction model to copy,
     and it is only possible because the page is real text, not a picture.
   - **Quran.com native apps** — the *pack management* model: browse/download/
     remove, size shown up front, resumable, works offline after install.
   - **Al Quran (word by word)** — the *switching* model: script choice sits in
     reader settings next to translation choice and re-renders in place.

   This makes the long-standing **"Exact-Mushaf page rendering"** backlog item
   (above, §MVP-out) a *consequence* of the Classic Madani pack rather than a
   separate project: shipping the pack as printed pages gives line-for-line
   rendering by construction. Consequences to accept up front: pinch-zoom
   becomes page-scale (a 15-line page cannot reflow, so the font-size slider
   hides), and it is a third *viewport* rather than a third value on
   `ArabicScript`. Reading view only — Detailed (Arabic + translations) stays
   flowing text.

   **→ Full implementation plan: [`mushaf-page-mode-plan.md`](mushaf-page-mode-plan.md)**
   (owner ask 2026-08-02). App only — explicitly **not** the website.
2b. **Full-text / verse-text search** — a dedicated search experience beyond
   the Home surah-name quick search. Scope should cover Arabic ayah text plus
   bundled/installed translation text, result snippets with highlighted matches,
   Surah:Ayah addressing, language/source filters, and direct reader deep-links
   to the matched ayah. Implementation likely needs an FTS5-backed index over
   `ayahs` + selected `translations`, with downloaded editions folded in without
   writing into the bundled `quran.db`.
3. ~~**Prayer start-time reminders**~~ — **SHIPPED 2026-08-04** (see Shipped
   above, "Salat notifications"). All-or-nothing (no per-prayer opt-in, no
   pre-prayer lead time yet — could still be added later); watch the OEM
   battery-killer problem already documented for reminders (OnePlus).
3b. **Dedicated Salah screen** (owner, 2026-08-04) — a proper prayer-times
   home surface, not just the Home pill + bottom sheet. Not scoped yet; likely
   candidates once picked up: a monthly calendar of times (not just today),
   qibla direction, per-prayer notification opt-in/lead-time (see #3 above),
   maybe a stronger visual tie to "Light of Day" phases. Design + scope owner
   sign-off needed before starting.
4. **More Sunnah occasions** — new Hijri month start, and the rest of the
   recurring calendar (Ayyam al-Beed already ships; candidates: the sacred
   months, Rajab/Sha'ban markers, Laylat al-Qadr odd nights). Extends
   `sunnah_events` + the occurrence engine; each new occasion needs a Hijri-date
   rule and a decision on whether it's informational or routes into the app.
   Anchor-table accuracy (see `quality-backlog.md` §14c) matters more once
   month-START events exist — those fire exactly on the boundary the anchors fix.
5. **More authentic translations, + Roman Urdu** — tracked centrally in
   `../alquran-data/TRANSLATIONS-ROADMAP.md`; the edition model + downloadable
   catalogue already support this, so new editions are a data-side job. Roman
   Urdu has its own repo (`../alquran-roman-urdu`) with a style guide and
   validation pipeline — that is the source, not a transliteration done here.

   **Bundle-size direction** (owner, 2026-08-03): over time, shrink
   `quran.db` so it carries the Quran text + indices + only the smallest
   first-run translation set. The likely long-term shape is:

   - **Always keep downloaded editions in `editions.db`, never `quran.db`.**
     The seed DB is overwritten on version bumps, so merging downloads into it
     would silently destroy reader downloads on app update.
   - **Prefer bundling Urdu as the flagship offline baseline.** Consider keeping
     one Hindi edition bundled if India/offline-first remains a v1/v2 priority.
     English should move to downloadable-only once the catalogue flow is proven.
   - **Do not show duplicate downloads for bundled slugs.** If `ur-junagarhi`
     is in `quran.db` and also appears in `catalogue.json`, the picker shows it
     once as on-device, never again under "Available for download". A
     same-language different slug, e.g. Roman Urdu, may still appear as a
     separate downloadable edition.
   - **Keep selection logic separate from packaging.** Smart defaults may choose
     Hindi/Urdu/English/Roman Urdu based on locale, but that must not decide
     whether a catalogue row is hidden. Duplicate suppression is based on
     physical presence by slug: bundled slugs + installed slugs.
   - **When removing built-in translations later, old saved selections must
     degrade safely.** If a previously bundled slug becomes downloadable-only,
     it should either remain available in the catalogue or fall back to the
     locale/default bundled edition without leaving the reader blank.

   **Roman Urdu is currently switched OFF** (owner, 2026-08-02):
   `FeatureFlags.romanUrdu = false`, applied in `translationResources()` —
   the one chokepoint the picker and the reader both read, so the edition
   cannot leak through one path while hidden on the other. Readers who had it
   selected fall back to the defaults (`_activeLangs` drops unavailable slugs).

   The reason is quality, and the ruling is **ours or none**: the bundled
   `ur-roman-junagarhi-experimental` is a third-party rendering (Al-QuranJino)
   that mangles خ (`qarch`), final ت (`hidaayath`), drops nasalisation (`hai`
   for ہیں) and fuses footnote markers into words in 309 verses
   (`parhezgaaro1`). Our own text is better and will replace it — do not
   re-enable the flag against the third-party edition, and do not try to clean
   that text app-side. The row stays in `quran.db`, unused.
6. **More reciters** — Maher al-Muaiqly, Saad al-Ghamdi, Sudais and others. The
   audio layer is already namespaced per reciter (`recitation/{reciter}_{bitrate}/`
   in both the R2 path and the on-disk cache), so no collision risk; the work is
   ingesting each reciter to R2 verse-by-verse against the same global 1..6236
   index, plus a reciter picker in reader settings (`reciterId` already persists).
   Licensing per reciter needs clearing exactly as for translations.
7. **An authentic Urdu reciter** — as #6, but specifically an Urdu-language
   recitation/translation audio for the core audience. Confirm what is wanted:
   Arabic recitation by a Pakistani/Indian qari, or Urdu *translation* audio
   played after each verse — they are different products and different data.
   **Deferred until authentic assets are handy** (owner, 2026-08-07): the
   desired product is Arabic ayah audio followed by Muhammad Junagarhi Urdu
   translation audio, and it should appear only in Detailed view (Reading mode
   remains Arabic-only). Public ayah-split Junagarhi audio has not been verified
   yet; Dar-us-Salam's Sudais/Shuraim + Maulana Muhammad Junagarhi MP3 set is
   the likely authoritative acquisition path, but needs source/licensing and
   ayah-splitting verification before implementation. Start with a Surah
   Al-Fatihah-only POC when revisited.
   **→ POC plan: [`dual-audio-urdu-poc-plan.md`](dual-audio-urdu-poc-plan.md)**
8. **Tajweed colours** — colour-coded pronunciation rules over the Arabic. Needs
   a tajweed-annotated source (QUL exports tajweed-rule Uthmani) and a rendering
   approach: the current KFGQPC text is a single styled run, so per-rule colour
   means parsing the annotation into spans — and it must not fight the IndoPak
   script option or pinch-zoom. Verify against a printed tajweed Mushaf before
   shipping; wrong colours are a correctness problem, not a cosmetic one.

**Not sized or scheduled** — this is a capture of intent, not a commitment. When
one is picked up, check the licensing gate first (translations, reciters and
tafsir editions all carry it) and give it a `FeatureFlags` entry so it can ship
dark.

## Reference

- Translation *editions* (which languages/editions, licensing, ingestion status) are tracked centrally in `../alquran-data/TRANSLATIONS-ROADMAP.md` — don't duplicate that list here.
- Web-specific product backlog (mobile responsiveness, conversion measurement, Juz/page library browsing) lives in `../al-quran-web/docs/product-backlog.md`.
- Reader/audio bug-level backlog lives in `quality-backlog.md` in this same folder.
