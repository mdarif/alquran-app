# LEARNINGS.md — Building a Flutter Quran reader

Hard-won, reusable learnings from **Al Quran** (Flutter, offline, KFGQPC Hafs +
Urdu/Hindi). Written so the *next* project skips the dead ends. Specifics over
platitudes — exact codepoints, commands, and root causes.

---

## 1. Arabic rendering in Flutter — the big one

### Flutter does not apply the `liga` OpenType feature for Arabic runs
- Flutter/Skia applies `init`/`medi`/`fina`/`isol`/`ccmp`/`calt`/`rlig`/`mark`/
  `mkmk` for Arabic, **but not `liga`** — and `FontFeature.enable('liga')` in a
  `TextStyle` does **not** force it (verified on a physical run, both Impeller
  and Skia).
- This bites when a font puts a **mandatory ligature under `liga`**. The old
  **KFGQPC Uthmanic Hafs v0.09 (2011)** put the lam-alef ligature (e.g. `وَلَا`)
  under `liga`, so the lam and alef rendered **detached**.

### The fix: use the HarfBuzz-compatible **KFGQPC HAFS V2 (Ver 0.18)**
- V2 forms the lam-alef via `rlig`/default features (which Flutter *does* apply),
  so it ligates even with vowels between the letters — and even with `liga` off.
- Source: QUL (https://qul.tarteel.ai); mirror
  `github.com/thetruetruth/quran-data-kfgqpc` → `hafs/font/hafs.18.ttf`.
  Download a single GitHub file as raw:
  `gh api repos/<owner>/<repo>/contents/<path> -H "Accept: application/vnd.github.raw" > out.ttf`
- Do NOT use the page-based **QPC V2** (604 fonts, one per Madinah page, PUA glyph
  codes) unless you're doing exact-Mushaf rendering — it needs a per-page layout
  data pipeline, not Unicode text.

### Diagnose font/shaping bugs HEADLESSLY before touching app code
`brew install harfbuzz` gives you the same shaper Flutter uses:
```bash
hb-shape font.ttf "وَلَا"                 # see the glyph sequence (ligature => 1 glyph or connected forms)
hb-shape --features=-liga font.ttf "وَلَا" # which feature carries the ligature?
hb-view  font.ttf "وَلَا ٱلضَّآلِّينَ" --output-file=out.png --background=ffffff --foreground=000000
```
- A HarfBuzz-native font ligates **identically with `liga` on or off**. If it only
  ligates with `liga` on, Flutter will render it broken.
- Parse the `cmap` (pure Python, no deps) to confirm the font covers every mark
  your text uses. `uharfbuzz` + `fonttools` (`pip install --break-system-packages`)
  for deeper GSUB inspection.

### Rule out layers in order: data → shaper → font → renderer → framework
For the lam-alef bug the culprit was **font feature + framework**, NOT:
- the renderer — same on `flutter run --no-enable-impeller` (Skia) as Impeller;
- the shaper — HarfBuzz ligated fine standalone;
- the data — codepoints were clean QPC Uthmani.
Screenshot the running sim and zoom in to compare faithfully:
```bash
xcrun simctl io booted screenshot out.png      # capture the live app
# then crop/upscale a region with PIL to inspect a single glyph
```

### `TextAlign.justify` is wrong for Arabic in Flutter
Flutter has no kashida justification — it stretches glyph/space advances, which
mangles Arabic. Use `TextAlign.start` with `textDirection: TextDirection.rtl`.

---

## 2. QPC Quran text data specifics

- `text_arabic_uthmani` ends each ayah with an **end-of-ayah marker**: a space +
  **Arabic-Indic digits** (U+0660–U+0669), sometimes the U+06DD ornament. Strip
  it if you render your own ayah numbers:
  `text.replaceAll(RegExp('[\\s۝٠-٩]+\$'), '')`
- The text is dense with QPC annotation marks the font must cover: U+0670 (dagger
  alef), U+0671 (alef wasla), U+06D6/D7/D8/DA/DB/DC (small high waqf signs),
  U+06DD (end of ayah), U+06DE (start of rub el hizb), U+06E1 (rounded sukun,
  ~37k occurrences), U+06E5/E6 (small waw/yeh), U+06E9 (place of sajdah), etc.
- **Bismillah header rules:** it *is* ayah 1 of Al-Fatihah (surah 1); At-Tawbah
  (surah 9) has **none**; show it as a header for the other 112 surahs. Pull the
  exact glyphs from Al-Fatihah 1:1 (stripped) so encoding matches the font.
- Western ("English") numerals come free from rendering an `int` (`'$n'`); keep
  ayah-number medallions in a plain sans face, not the Quran font.
- **All QPC index columns are global and monotonic** — juz 1–30, hizb 1–60,
  rub-el-hizb 1–240, page 1–604, ruku 1–558 (ruku does NOT reset per surah). So
  "ayahs of juz N" is just `WHERE juz_number = N ORDER BY id` and a section can
  span surahs cleanly. For navigation lists, the first ayah of each index value
  is one grouped query:
  `SELECT col, surah_id, ayah_number FROM ayahs a WHERE a.id = (SELECT MIN(b.id) FROM ayahs b WHERE b.col = a.col) ORDER BY col`.
- When a reader section spans surahs, group consecutive ayahs by `surah_id` and
  draw a chapter header per group; show the Basmala only when a group starts at
  `ayah_number == 1` (so a juz that begins mid-surah correctly omits it).

---

## 3. Flutter reading-UX patterns that worked

- **Pinch-to-zoom without breaking scroll/selection:** do NOT use
  `GestureDetector.onScaleUpdate` — its ScaleGestureRecognizer wins the gesture
  arena and kills the scroll view. Use a raw `Listener`, track pointers in a
  `Map<int, Offset>`, and on 2 pointers compute the distance ratio to scale the
  font. `Listener` doesn't enter the arena, so scroll + text selection still work.
- **Selectable text / copy:** wrap the reader body in `SelectionArea`. Exclude
  inline non-text widgets (e.g. verse-number medallions) with
  `SelectionContainer.disabled(child: …)` so a copied passage is pure Quran text.
- **Inline ayah-end markers:** `Text.rich` + `WidgetSpan(alignment:
  PlaceholderAlignment.middle, child: medallion)`. Each ayah is one `TextSpan`
  so intra-ayah shaping stays intact.
- **`SelectionArea` eats horizontal drags.** A parent `GestureDetector.onHorizontalDragEnd`
  (or a `PageView`) won't fire when wrapped around/under a `SelectionArea` —
  selection claims the drag in the gesture arena. Fix: detect the swipe in a raw
  `Listener` (pointer down/up positions, distance-based), which observes pointer
  events outside the arena — the same trick used for pinch-zoom. One Listener can
  do both: 2 pointers → pinch, 1 pointer with a mostly-horizontal displacement
  past a threshold → swipe (guard with a `_multiTouch` flag so a pinch is never
  read as a swipe).
- **Swipe-between-sections without losing state:** keep one cubit, change its
  target in `State`, and reload. Show the previous content while the next loads
  (`if (ayahs.isEmpty) spinner; else content`) to avoid a spinner flash, and key
  the scroll view by the section's first ayah id so a *new* section starts at the
  top while a same-section rebuild keeps its scroll offset.
- **Persisting reading prefs:** register `SharedPreferences` as a GetIt singleton
  loaded once at startup, expose it behind a repo with **synchronous getters**
  (so `State` can initialize `late` fields directly — no FutureBuilder flicker)
  and async setters. Fire setters with `unawaited(...)` (satisfies the
  `unawaited_futures` lint). For pinch-zoom, persist the **final** value on
  pointer-up, not on every move, to avoid write spam.
- **Centralize the Arabic style** once (`QuranTextStyle.madani`) and
  `.copyWith(fontSize: …)` at call sites — avoids drift across widgets.
- **Urdu needs a Nastaliq font.** The platform default renders Urdu poorly. Bundle
  **Noto Nastaliq Urdu** (Google, SIL OFL — license-clean) with extra line height
  (~2.0). Jameel Noori Nastaleeq looks great but its licence is murky.
- **Icon gotcha:** `Icons.translate` shows a 文/A glyph that reads as "Chinese";
  prefer `Icons.subject` / `Icons.menu_book` for a reading/translation toggle.

---

## 4. Flutter project & build mechanics

- **Drift:** run `dart run build_runner build` before `flutter analyze`, or it
  errors on missing `*.g.dart`. With a prepopulated asset DB, keep
  `migration.onCreate` a **no-op** (tables already exist); set
  `case_from_dart_to_sql: snake_case` in `build.yaml` so camelCase getters map to
  snake_case columns.
- **Platform folders** (`android/`, `ios/`) are generated by `flutter create` and
  gitignored; regenerate, don't commit.
- **Font/asset changes need a full rebuild** (hot reload won't pick them up).
- **`native_assets … references objective_c` build error** after clearing caches
  → fix with `flutter clean && flutter pub get`.
- **Disk:** iOS builds + `~/Library/Developer/Xcode/DerivedData` balloon fast and
  a full disk fails builds with `errno 28`. DerivedData is regenerable; clearing
  it is safe.
- Lint `require_trailing_commas` is on — multi-arg calls need trailing commas.
- **`dart format` vs `require_trailing_commas` conflict:** when args fit on two
  lines, the formatter wraps them WITHOUT a trailing comma, but the lint then
  flags it — an endless tug-of-war. Fix by writing the call fully expanded with a
  trailing comma (one arg per line); the formatter then leaves it alone. Decide
  per project whether to keep both — they only clash on these borderline wraps.
- **Cheap, high-leverage tooling** (ported from a sibling app): a `Makefile`
  task runner (`make ci` = format-check + analyze + test), a `.githooks/pre-push`
  mirroring CI (`git config core.hooksPath .githooks`), a GitHub Actions workflow
  (remember: run `build_runner` before analyze since `*.g.dart` is gitignored),
  stricter `analysis_options` (`strict-inference`, `unawaited_futures`), and
  `cliff.toml` for changelog-from-conventional-commits. All architecture-agnostic.

---

## 5. Methodology meta-learnings

- For a **visual bug**, reproduce it outside the app first (hb-view PNGs, cmap
  dumps). Two blind "evidence-based" code fixes still missed because the real
  variable (Flutter not applying `liga`) only showed on-device — so build a tiny
  **on-device diagnostic screen** rendering the artifact in N configurations and
  read the answer from one screenshot.
- You can screenshot and inspect a **user's already-running** sim
  (`xcrun simctl io booted screenshot`) — no need to launch your own instance and
  fight the flutter startup lock (especially if a Patrol test is running).
- Prefer the **official upstream fix** (V2 font) over a clever local hack (we had
  a working GSUB patch moving `liga` lookups into `calt`, but discarded it).

---

## 6. Licensing (clear before any release)
- **KFGQPC** fonts: licence UNVERIFIED — the King Fahd Complex terms must be
  confirmed for redistribution in an app store build.
- **Noto Nastaliq Urdu:** SIL OFL 1.1 — clean.
- Translations (Junagarhi Urdu, al-Umari Hindi) and any audio: verify separately.
