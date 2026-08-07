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
- **Multiple translations, multi-language** — Urdu (Junagarhi, default), Hindi (Suhel Farooq Khan/Nadwi), English (Hilali & Khan) bundled in the current seed; Roman Urdu by Abu Rayyan (`ur-roman-abu-rayyan`) ships as an opt-in transliteration edition. The edition model (data repo, 2026-07-28) supports several editions per language and on-demand downloads via a Translations screen reading a CDN catalogue. A translation slug must appear in exactly one visible bucket: bundled/on-device, installed/on-device, or available for download — never both bundled and downloadable.
- **Continue reading** — resumes the exact verse, in the viewport you left off in; the open stamp waits for a dwell so a glance can't overwrite a deep position.
- **Light of Day** — time-adaptive theming (pillar 1 of 3; shipped as the "dark mode" answer instead of a literal toggle).
- **Prayer times sheet** — Karachi method + Shafi Asr (hard-wired, no other madhab options), Hijri date shown.
- **Reader virtualization** — page-chunked lazy list, ~17-31ms open time.
- **Bookmarks** — ayah-level, multiple, with a bookmarks screen (`AyahBookmarkRepository`, verse address only — no notes/tags yet).
- **Sunnah reminders** — local notifications for Al-Kahf (Friday), White Days, Ashura, Arafah, Dhul Hijjah; the Al-Kahf one routes into the reader and resumes where you left off.
- **Salat notifications** — local notifications at each of the 5 daily prayer times (2026-08-04, `FeatureFlags.prayerTimeNotifications`); tapping one opens the Prayer Times sheet. Both reminder types now live on one unified "Reminders" screen (uniform toggle + info popover per row), reachable from the Home overflow. All-or-nothing today: no per-prayer opt-in and no pre-prayer lead time yet.
- **Tafsir** — per-ayah Tafsir surfaced in the Detailed view via a bottom sheet, plus a Translations-style manager screen (browse a CDN catalogue, download/remove editions, catalogue visibility flags). No `FeatureFlags` gate — ships unconditionally. Data side: a `tafsir` resource type + table parallel to `translations`, ayah-range aware; two editions are ingested so far (Tafsir Ibn Kathir English abridged + Urdu, `../alquran-data/config/tafsir.yaml`). More editions are data-side work tracked with translation editions in `../alquran-data/TRANSLATIONS-ROADMAP.md`. See `lib/features/tafsir/`.
- **Roman Urdu by Abu Rayyan** — `ur-roman-abu-rayyan` is live as the Al Quran-owned Roman Urdu transliteration, credited to Abu Rayyan. It is opt-in (`default_on: false`), visible in the Translations flow, and not hidden by the app-side Roman Urdu flag. Source of truth: `../alquran-roman-urdu`; updates ship through the data/catalogue pipeline, not app-side text fixes.
- **Soft app-update reminder** — a dismissible Home banner + a Settings "Check for Updates" row read a shared `AppUpdateCubit`, backed by a small remote JSON config (`FeatureFlags.softUpdateReminder`). Manual checks always resolve to an in-app result (available / up to date / couldn't check); required updates (via `minimumSupportedVersion`) can't be dismissed; "Later" only suppresses the exact version dismissed. See `lib/features/app_update/` and `docs/error-handling-runbook.md`.
- **Read quick navigation** — the Read screen now exposes compact Surah/Juz/Page pills below Continue Reading. Juz and Page update the current Read body in place and then open the immersive Reader when a row is selected. Data comes from the existing index columns in `quran.db`; no new data pipeline work.

## Built but flagged OFF for v1

- **Hizb / Ruku advanced navigation** — DB carries the indices (hizb 1–60, ruku 1–558, rub 1–240, 15 sajdas) and the index-list code can still render them, but the first visible Read quick-navigation slice intentionally ships only Surah/Juz/Page. Revisit Hizb/Ruku later as a secondary "more reading options" affordance if readers ask for it.
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

## Immediate roadmap extensions — recommended next sprints (2026-08-07)

The core reader, translation layer, and Tafsir engine are now complete enough to
move the product from a feature-rich reader toward a more immersive app platform.
These are the recommended technical milestones to pick up before adding larger
new content surfaces.

1. **Top-level mobile navigation redesign.** Move away from hiding core features
   in the Home overflow by introducing a clear four-tab shell: Read, Prayer,
   Library, and More. Keep the Reader itself as an immersive pushed route.
   Library should expose Translations and Tafsir; Prayer should promote the
   existing prayer-time/reminder surface; More should hold bookmarks, settings,
   updates, and app information. This is now the preferred next product slice.
   **→ Full implementation plan: [`navigation-redesign-plan.md`](navigation-redesign-plan.md)**
2. **Audio layer modernization — move beyond foreground-only playback.** Upgrade
   the recitation stack from an in-screen `just_audio` player/cubit to an
   asynchronous background architecture using `audio_service` on top of the
   existing self-hosted CDN + cache setup. Users expect long Surahs to keep
   playing from the notification drawer and lock screen, with play/pause,
   previous/next ayah, progress, and interruption handling. This is also the
   clean foundation for interleaved multi-stream playback: Arabic ayah audio,
   then Maulana Muhammad Junagarhi Urdu translation audio, stitched as a single
   managed queue.
3. **Update and error-state polish.** Finish the update UX fixes and first pass
   from `docs/error-handling-runbook.md`: manual "Check for Updates" must bypass
   a previous Later tap, new versions must re-show the banner, catalogue/CDN
   failures need calm retry states, and already-downloaded content must stay
   usable offline.
4. **Detailed-view immersion polish.** Prepare the Detailed view for heavier
   learning modes: better spacing between Arabic/translations/Tafsir, lighter
   per-ayah actions, consistent download/error affordances, and room for a future
   audio mode selector without disturbing Reading mode.

## Roadmap — owner's next-version list (2026-08-01)

Ordered as the owner raised them, not by priority. Each notes where the work
actually lands, since most of these start in `../alquran-data`, not here.

1. **Downloadable script / Mushaf text packs** — **P1**. Add separately
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
2. **Full-text / verse-text search** — a dedicated search experience beyond
   the Home surah-name quick search. Scope should cover Arabic ayah text plus
   bundled/installed translation text, result snippets with highlighted matches,
   Surah:Ayah addressing, language/source filters, and direct reader deep-links
   to the matched ayah. Implementation likely needs an FTS5-backed index over
   `ayahs` + selected `translations`, with downloaded editions folded in without
   writing into the bundled `quran.db`.
3. **Dedicated Salah screen** (owner, 2026-08-04) — a proper prayer-times
   home surface, not just the Home pill + bottom sheet. Not scoped yet; likely
   candidates once picked up: a monthly calendar of times (not just today),
   qibla direction, per-prayer notification opt-in/lead-time,
   maybe a stronger visual tie to "Light of Day" phases. Design + scope owner
   sign-off needed before starting.
4. **Friday home shortcut / Juma mode** — a Friday-specific Home surface that
   reduces the common Friday path to one tap. On Fridays, show a prominent,
   tasteful entry point for Surah Al-Kahf and, once background audio is ready, an
   Al-Kahf playback action. Keep it contextual and quiet: it should feel like a
   helpful nudge, not a recurring marketing banner. This can build on the
   existing weekday logic, Al-Kahf reminder route, and Prayer Times sheet.
5. **Islamic occasion greetings** — lightweight Home greetings for days that
   matter to Muslim readers: Juma Mubarak, Ramadan Mubarak, Eid Mubarak, and
   similar major occasions. This should use the same Hijri/calendar source as
   reminders so the app does not show the wrong greeting for a user's region or
   Maghrib rollover. Keep copy short and avoid cluttering the reading-first Home.
6. **Large vowel / Clear Vowels mode for IndoPak readers** — an accessibility
   setting for elders and readers who struggle with small Zabar/Zer/Pesh marks in
   the Noorehuda IndoPak script. Proposed user-facing name: **Clear Vowels
   Mode**. When enabled, increase line spacing and render vowel marks with a
   high-contrast color while keeping the main letters neutral. Implementation is
   not just a color toggle: it needs reliable parsing of Arabic combining marks
   into spans, verification against the Noorehuda font, and screenshots on small
   Android devices to make sure marks remain correctly attached to their letters.
7. **More Sunnah occasions** — new Hijri month start, and the rest of the
   recurring calendar (Ayyam al-Beed already ships; candidates: the sacred
   months, Rajab/Sha'ban markers, Laylat al-Qadr odd nights). Extends
   `sunnah_events` + the occurrence engine; each new occasion needs a Hijri-date
   rule and a decision on whether it's informational or routes into the app.
   Anchor-table accuracy (see `quality-backlog.md` §14c) matters more once
   month-START events exist — those fire exactly on the boundary the anchors fix.
8. **More authentic translations, + Roman Urdu review updates** — tracked
   centrally in `../alquran-data/TRANSLATIONS-ROADMAP.md`; the edition model +
   downloadable catalogue already support this, so new editions are a data-side
   job. Roman Urdu has its own repo (`../alquran-roman-urdu`) with a style guide
   and validation pipeline — that is the source, not a transliteration done here.
   Remaining Roman Urdu work is review, corrections, and future catalogue
   refreshes for the shipped Abu Rayyan edition.

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

   `FeatureFlags.romanUrdu = false` now means only one thing: keep the retired
   third-party `ur-roman-junagarhi-experimental` row (Al-QuranJino / Muhammad
   Kazim) hidden from the reader and Translations picker. That rejected row is
   also disabled in the data catalogue, but remains in `quran.db` as a
   reproducible comparison artifact. Do not re-enable it, delete it, or try to
   clean it app-side.
9. **More reciters** — Maher al-Muaiqly, Saad al-Ghamdi, Sudais and others. The
   audio layer is already namespaced per reciter (`recitation/{reciter}_{bitrate}/`
   in both the R2 path and the on-disk cache), so no collision risk; the work is
   ingesting each reciter to R2 verse-by-verse against the same global 1..6236
   index, plus a reciter picker in reader settings (`reciterId` already persists).
   Licensing per reciter needs clearing exactly as for translations.
10. **Audio layer modernization + authentic Urdu translation audio** — first move
   the existing foreground-only ayah recitation into a background-capable
   `audio_service` architecture with notification drawer / lock-screen controls,
   queue state, interruption handling, and the existing self-hosted CDN cache.
   After that foundation is in place, add Urdu-language translation audio for the
   core audience. Confirm what is wanted for each audio mode: Arabic recitation
   by a Pakistani/Indian qari, or Urdu *translation* audio played after each
   verse — they are different products and different data.
   **Deferred until authentic assets are handy** (owner, 2026-08-07): the
   desired product is Arabic ayah audio followed by Muhammad Junagarhi Urdu
   translation audio, and it should appear only in Detailed view (Reading mode
   remains Arabic-only). Public ayah-split Junagarhi audio has not been verified
   yet; Dar-us-Salam's Sudais/Shuraim + Maulana Muhammad Junagarhi MP3 set is
   the likely authoritative acquisition path, but needs source/licensing and
   ayah-splitting verification before implementation. Start with a Surah
   Al-Fatihah-only POC when revisited.
   **→ POC plan: [`dual-audio-urdu-poc-plan.md`](dual-audio-urdu-poc-plan.md)**
11. **Tajweed colours** — colour-coded pronunciation rules over the Arabic. Needs
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
