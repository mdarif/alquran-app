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
mangles Arabic. Use `TextAlign.start`/`center` with `textDirection: rtl`.

### Adopt the matched text+font PAIR — stop hand-fixing Arabic data (2026-06-21)

> **CORRECTION (2026-06-22): the "drop grafting" decision below was WRONG.**
> Adopting the matched text+font pair was right, but the claim that the *bare*
> golden text renders madd correctly held only in HarfBuzz/freetype (and the
> quran.com web reader) — **NOT in Flutter on-device**, where the zero-width
> superscript-alef+maddah loses its GPOS anchor and detaches/floats (in BOTH
> Impeller and Skia; confirmed `flutter clean` + `--no-enable-impeller` still
> broken). **Tatweel-carrier grafting (Bug 2) is REQUIRED and has been
> re-instated** in `alquran-data/pipeline/build_db.py` (`graft_tatweel_carriers`,
> driven by the `tatweel_reference` key in `sources.yaml`): it grafts the
> canonical kashidas onto the golden text at build time (535 → 1652, letters
> unchanged), and `verify_db.py` guards the 1652 count + an Al-Maidah 5:1 canary.
> Mark-stripping (§2) stays superseded. The mark-anchoring `mark`/`mkmk`/`ccmp`
> font features did NOT help (they're HarfBuzz defaults already applied) — only
> the carriers fix it.

The madd/tanween/mark hacks all came from the same mistake: **pairing a text source
with a font it wasn't authored for.** github.com/quran (quran.com / quran-ios) has no
secret dataset — it ships the QPC Hafs text **`quran.ar.uthmani.v2.db`**
(`quran/quran-ios` → `Domain/QuranResources/Databases`) rendered with a matched KFGQPC
HAFS font (quran-ios uses the Bold `UthmanicHafs1B Ver13`; **we ship the Regular cut
`UthmanicHafs1 Ver18`** from quran.com web — lighter and no iOS weight-fallback, see
the font-weight gotcha below). Text and font are co-designed for letters/shaping —
BUT (see the 2026-06-22 correction above) the golden text ships madd `يَٰٓأَيُّهَا`
**bare** (`U+0670 U+0653`, only 535 tatweels) and Flutter does NOT anchor those
bare marks on-device. So we graft the canonical tatweel carriers back on at build
time: `config/sources.yaml` → `arabic_uthmani` reads `quran.ar.uthmani.v2.db` and
adds a `tatweel_reference: sources/quran-uthmani-tanzil.json`; `build_db.py`'s
`graft_tatweel_carriers` diffs the two and copies ONLY the pure-tatweel runs
(535 → 1652, letters/spacing untouched). U+06ED tanween marks are kept (98×), not stripped.
`convert_ghanem.py` is deleted. **Rule: use the font the text was made for — and on
Flutter, give zero-width superscript marks a tatweel carrier or they detach.** Bismillah is already a separate header in the
golden text (not bundled in each surah's ayah 1) and ayahs carry no trailing
number glyph, so even the strips are unnecessary. The golden text uses the QPC
**shadda-before-vowel** combining order (`U+0651 U+064E`, NOT NFC-canonical) — do not
NFC-normalize it, and the app's `_bismillah` constant was made byte-exact to it.
(Impeller still must stay off — Bug 1 below — that's renderer-level, not data.)

> **Font-weight gotcha (cost two debug cycles) → use the Regular cut.**
> `UthmanicHafs1B Ver13` (quran-ios's face) is a **Bold** cut: OS/2
> `usWeightClass=700`, `head.macStyle` bold bit set, subfamily "Bold". Declared in
> `pubspec.yaml` with no `weight:` (Flutter assumes 400), **iOS silently falls back
> to a system Naskh font** — the whole page is the wrong typeface even though the
> cmap is complete (easy to miss: it still looks "fully diacriticised"). Declaring
> `weight: 700` + `fontWeight: FontWeight.w700` makes it match, but then it just
> renders heavy/clunky. **The real fix: ship the Regular/400 cut —
> `UthmanicHafs1 Ver18`, the face quran.com's *web* reader uses** (Quran Foundation
> CDN, woff2→ttf, glyphs unchanged). It renders the same bare golden text correctly
> (madd/tanween) AND composes the digit→rosette, is lighter/elegant, and matches
> with no weight workaround. Don't edit a font's metadata to force a weight (KFGQPC
> must not be modified) — pick the cut you actually want. **After any font change,
> `flutter clean` + delete the app before re-running** — hot reload/restart does NOT
> re-read `pubspec` font declarations or re-bundle assets, and iOS caches font
> registration aggressively (a DB asset can update at runtime while the font does
> not, which masks the problem). Always verify a font's weight (`OS/2.usWeightClass`,
> `head.macStyle`) and shaping (`hb-shape`/`hb-view`) before shipping it.

### Elongated madd (يَٰٓأَيُّهَا) — TWO independent bugs, both had to be fixed

This one took a long, winding investigation with several wrong turns. The final, verified
truth is that **two separate bugs stacked on top of each other** — fixing either alone
left it looking broken, which is what kept sending us back to the wrong layer.

**Bug 1 — Renderer (iOS Impeller).** Impeller (default on iOS since Flutter 3.16) does
not correctly apply Arabic OpenType GPOS positioning (`calt` contextual alternates and
`mark`/`mkmk` anchors). The superscript-alef+maddah collapses small and low onto the
preceding glyph. Skia applies it correctly. **Fix:** disable Impeller.
```xml
<!-- ios/Runner/Info.plist -->
<key>FLTEnableImpeller</key>
<false/>
```
Confirm with `flutter run --no-enable-impeller` (the flag bypasses build caching; the
Info.plist needs a `flutter clean` to actually take — a plain re-run keeps the stale
bundle, which fooled us into thinking Impeller was already off when it wasn't).
**Gotcha:** `ios/Runner/Info.plist` is gitignored (platform folders are regenerated by
`flutter create`), so this fix is NOT version-controlled — re-apply after any `ios/` regen.

**Bug 2 — Data (missing kashida carriers).** The QUL **word-by-word** source
(`qpc-hafs-word-by-word.db`) omits the **tatweel (U+0640)** kashidas that the canonical
Uthmani edition carries. Superscript marks (madd `ٰٓ`, dagger-alef `ٰ`, hamza `ٔ`) are
zero-width; without a kashida to sit on, the font stacks them onto the previous letter.
The canonical text inserts a tatweel as the carrier (`يَـٰٓأَيُّهَا`, `ٱلصَّـٰلِحَٰتِ`,
`بِـَٔايَٰتِ`, `إِسۡرَـٰٓءِيلَ`) — **1652 of them**. Ours had none.

**What cracked it:** comparing our text to the **canonical Uthmani edition** (Tanzil
lineage, e.g. `risan/quran-json`). They are the *same letters* (6236/6236 verses match;
after stripping tatweels only ~200 differ, all incidental spacing). The canonical just
*has the kashidas*. Don't hand-derive a rule for where they go — I tried (insert after
"connecting letters"), and got reh wrong (it's "right-joining" yet canonical DOES carry
it). The canonical placement is authoritative.

**The fix that worked** (`alquran-data/pipeline/prepare_sources.py`): diff our joined
QUL text against the canonical text and graft across **only the pure-tatweel runs**
(`difflib.SequenceMatcher`, copy `insert`/`replace` opcodes whose chars are all U+0640).
Letters and spacing stay ours; we gain exactly the canonical kashidas. This is also the
cleanest licensing posture — we transfer kashida *positions*, not anyone's text. The
canonical file lives at `sources/quran-uthmani-tanzil.json` (build-time only).

**Dead ends, recorded so we don't repeat them:**
- *"Insert U+0640 only after يَ"* (the first narrow fix) — fixed يَٰٓأَيُّهَا but left
  every other base (ayn `شَعَٰٓئِرَ`, lam, dagger-alef, hamza) broken. Whack-a-mole.
- *"hb-shape says bare يَٰٓ + `calt` gives the wide glyph, so leave it bare and the
  tatweel is counterproductive"* — **misleading.** Bare+calt yields a wide yaa but the
  maddah floats high (wrong); it only *looked* like the font's ceiling because Impeller
  was ALSO broken and we never saw correct output. The canonical tatweel rendering is
  what the printed mushaf and every working app actually use.
- *Swapping to Amiri Quran* — seats the madd but restyles all Arabic to Naskh ("odd"
  against the Madani script). Rejected; KFGQPC stays the single face.
- *QPC V2 page fonts* — exact mushaf, but fixed 15-line pages break pinch-zoom/reflow
  (a hard PRD requirement). Out of MVP.

**General rule:** when the *copied text* is right but the *display* is wrong, it's the
renderer or the font — not the data. When the text itself is suspect, **diff it against a
canonical edition** before inventing transformation rules; the canonical encoding already
encodes the right answer (here, where kashidas go).

**Elongated madd on word-final `ـىٰ` (ٱلۡيَتَٰمَىٰٓ, حَتَّىٰ, ٱلۡأَعۡمَىٰ): ROOT CAUSE = inconsistent
GPOS mark anchors across the alef-maqsura glyph FAMILY; FIX = lift them all in the font
(`tool/patch_arabic_font.py` + `make patch-font`).** Took many wrong turns — record the *method*.
- **Symptom:** the dagger-alef / composed dagger-alef+maddah on a word-final alef-maqsura hugs the
  letter instead of floating above it.
- **Root cause:** KFGQPC ships the word-final alef-maqsura as a whole **family** of contextual /
  Tajweed-form glyphs (`afii57449`, `afii57450.zz04`, `TJ043 TJ062 TJ065 TJ067 TJ082 TJ083 TJ136`,
  selected by `calt`/joining context). Their **GPOS mark-to-base base-anchors** for `uni0670`
  (dagger) and `uni0670_uni0653` (composed madd) are **inconsistent**: the standard `afii57449`
  seats the madd at **Y=550**, but several Tajweed forms seat it at **75–350**. So whichever words
  land on a low-anchored form show a collapsed madd. **Quantify it:** shape all 664 `ـىٰ` words from
  the DB, read the final-cluster mark's y-offset → 138 good (afii57449/550), ~166 low. **Do this
  census FIRST** — it's what turned "one meem word" into "a family of 166 across 7 glyphs" and
  stopped the one-glyph-at-a-time whack-a-mole (e.g. حَتَّىٰ uses `TJ082`, not `TJ065`).
- **Fix:** raise the base-anchors. `tool/patch_arabic_font.py` finds the reference (`afii57449`'s
  madd anchor) and, for **every base glyph that carries the composed-madd anchor** (= exactly the
  alef-maqsura forms — nothing else takes `uni0670_uni0653`), lifts its dagger + madd base-anchors
  to the reference. **No GSUB edits**, so every glyph keeps its shape and all ligatures/contextual
  forms are untouched (Allah/Bism verified). Idempotent. **Gotcha:** the *base* anchor and the
  shaped *net* y-offset differ by the mark's own anchor, which varies by mark-class — so 14
  `مَىٰ`+maddah words net 425 not 550 even after the lift; visually identical (the composed madd is
  a tall glyph) so left as-is. **Licensing:** modifying KFGQPC is unverified-on-unverified — clear
  before release.

**Dead ends (do not repeat):**
- *"It's the data / a missing tatweel carrier."* WRONG — our text is **byte-identical to canonical
  Tanzil** (diff the codepoints: `quran-uthmani-tanzil.json['4:2']`). Never a data problem.
- *"It's canonical, accept it."* WRONG — the owner was right that other KFGQPC apps render it
  cleanly; the font *can* do it, the Tajweed swap is the defect.
- *"Disable `calt` globally."* Lifts the madd but **shatters the Allah ligature** (`Allah`→5 glyphs),
  widens text so Bismillah wraps. (`calt` is default-ON; to disable you need
  `FontFeature.disable('calt')`, not just omitting it — omitting ≠ off.)
- *"Per-word `-calt` on `مَىٰ` words."* **The worst trap, because it half-works.** Disabling `calt`
  for a whole word disrupts **every** mark in it: it lifts the final madd but shoves the *taa's*
  dagger-alef from y=375 to **y=975** (flies off). And a *broad* "any `ـىٰ` word" rule also shifts
  already-correct words (`إِلَىٰٓ`, `نَصَٰرَىٰ`) right — the "half fixed" report. Font-feature
  overrides are per-span and per-word at best; you cannot scope them to one glyph, so they are the
  wrong tool for a glyph/anchor defect.
- *"Neutralise the one Tajweed substitution (`TJ065→identity`)."* **Incomplete — fixed 1 of a
  family.** It cured the meem words but left `حَتَّىٰ`/`أُنثَىٰ` (TJ082), `لَيَطۡغَىٰ` (TJ083), etc.
  still low. **Lesson: before fixing one instance, census the whole set** (shape all N candidates,
  bucket by the offending glyph/anchor) so you fix the family in one pass.

**The method that finally worked (general rule for "font renders X wrong"):**
1. **Diff your text against a canonical edition** → rules out data (it did — byte-identical).
2. **Other apps use the same font fine?** → the font is capable; the defect is in a glyph/feature/
   anchor, find it (don't conclude "canonical, accept it").
3. **`hb-shape` with/without each feature** to localise (here `-calt` showed a `calt` chain swapping
   in a low-anchored Tajweed glyph).
4. **CENSUS the whole affected set**, not one example: shape every candidate word, read the mark's
   y-offset, bucket by base glyph → reveals the *family* and which are low vs the good reference.
5. **Dump GSUB/GPOS with fontTools**; prefer **fixing the GPOS anchor** (shape-preserving, hits the
   whole family) over GSUB substitution edits (per-glyph, changes shapes). A glyph/anchor defect is
   fixed in the font, never with per-word feature hacks in the app.

(Impeller-off is still set in the native manifests — Android:
`io.flutter.embedding.android.EnableImpeller=false`; iOS: `FLTEnableImpeller=<false/>` —
and a manifest change needs `flutter clean` to take. But on 3.41 it is no longer the cause
of this specific bug.)

**The "stale build / numeral canary" theory was WRONG — it was the wrong widget.**
When the user kept reporting the verse number as a Latin `2` after "fresh installs", I
concluded the device was running stale code (canary: pure-Dart `٢` can't be a renderer
bug, so a Latin `2` means old code). **False.** The device WAS on current code — I had only
fixed the chapter-header medallion (`SurahHeaderCard`) and never the widget the user was
actually looking at: the **Detailed-view ayah badge** (`ayah_tile.dart`), which still
rendered `'${ayah.ayahNumber}'`. There were *several* number-badge sites
(`ayah_tile`, `surah_tile` leading circle, `index_list_view` leading circle, the chapter
medallion); patching one and declaring victory is whack-a-mole. **Lesson: when a UI value
"won't change", grep for EVERY widget that renders it (`grep "ayahNumber}\|surah.id}\|\.number}"`)
before concluding it's a build/cache problem.** A screenshot localises which widget — the
green `CircleAvatar` badge is `ayah_tile`, the ornate rosette is the KFGQPC text glyph.

**Numeral convention — FINAL (owner-decided):** every verse/surah number is a **Western digit**.
- **Plain UI chrome badges** (TOC surah circle, chapter-header medallion, Detailed-view ayah
  badge, nav-index circle) are `'$n'`. (An Urdu-digit experiment on these was tried and reverted.)
- **Reading-view ayah marker = INVISIBLE U+06DD anchor + overlaid circle badge** (`_MarkedParagraph`).
  The font's ornate rosette read as "not real" inline, so the owner asked for the clean
  CircleAvatar-style badge from the Detailed view. Render the **empty ayah ornament U+06DD (`۝`)
  inline but TRANSPARENT** (`Color(0x00000000)`) — it reserves the inline slot and is the
  *measurable anchor* (U+06DD boxes cleanly; see the getBoxes caveat in §3), but draws nothing.
  Then **overlay** a real circle widget (`Container`, `BoxShape.circle`, `cs.primaryContainer`
  fill + `onPrimaryContainer` Western digit in a `FittedBox(scaleDown)`) centred on each anchor's
  box, sized to `rect.shortestSide`. An overlay (not a `WidgetSpan`, which bidi-reverses) keeps
  RTL order + reflow + pinch-zoom. Measure the box with `getBoxesForSelection(offset, offset+1,
  BoxHeightStyle.tight)` (works for the isolated U+06DD) in a post-frame callback with a *guarded*
  setState. Graceful degradation: if a box mis-measures you get no badge (a gap), not a crash.
  Offset bookkeeping: the marker is ALWAYS the single char `۝`, so `_verseStart` advances
  `textLen + 3` (` ۝ `), NOT the digit length.
- **Why an overlay at all (not the native rosette, not inline text):** KFGQPC's GSUB composes
  Arabic-Indic U+0660–U+0669 into the rosette (`٢`→`_771`) — but `٢` reads like Urdu `۴` to the
  audience (3+ rounds of "it still shows 4"; prove `٢≠4` with `hb-view ... "١ ٢ ٣ ٤"`). The rosette
  can ONLY hold the canonical `٢` (feeding it U+06F2 → bare `uni06F2`; KFGQPC has no enclosing-circle
  U+20DD → `.notdef`). So a clean circle around a *readable* digit MUST be a Flutter-drawn overlay
  on an invisible text anchor. Evolution across rounds: native rosette `٢` → plain Urdu `۲` (dropped
  circle) → ornate U+06DD medallion + Western digit overlay → **invisible U+06DD anchor + Flutter
  circle badge matching the Detailed view**.

### Waqf/iqlāb marks "float" — it's the Ver18 font, not a bug; the fix is QCF (backlog)

Owner flagged the small-high-jīm waqf mark (U+06DA `ۚ`) and the iqlāb meem (U+06ED `ۭ`)
rendering high/detached above the word (seen on 18:48 `مَرَّةِۭۚ`), vs a tighter
black-background reference. Ran it down headlessly and the verdict is: **nothing is
broken — the text and the rendering are both correct.**
- **Text is exact.** 18:48 is byte-for-byte identical to quran.com `text_qpc_hafs`
  (verify against `text_qpc_hafs`, NOT `text_uthmani`; see §2). The kasratān collapses to
  a single kasra + small meem because tanwīn-before-`ب` is **iqlāb**.
- **Render is faithful.** `hb-shape` with our exact features (`calt,rlig,liga`) anchors the
  marks correctly (non-zero `@x,y`); only forcing `-mark,-mkmk` collapses them to the origin.
  `hb-view` of the word matches the device (Impeller is off both platforms, so Skia/HarfBuzz
  == the headless render). So the float is **how UthmanicHafs1 Ver18 draws U+06DA**, app-wide:
  the plain waqf jīm is in **1,570 ayahs (25%)** and floats the same in all of them (the
  `ۭۚ` stack is only 7 ayahs: 16:28, 16:101, 18:48, 32:10, 39:49, 46:35, 59:14).
- **Our font IS quran.com's.** `UthmanicHafs1-Ver18.ttf` is the same file quran.com's web
  reader ships for its *Uthmanic Hafs* option (their CDN woff2→ttf, glyphs unchanged). So
  quran.com's *Unicode* option looks identical to us. The tight reference is quran.com's
  **default page-based QCF font** (printed-Madinah-page glyphs) = the PRD's backlogged
  **exact-Mushaf rendering**.

**Why there is no low-risk font fix:** the text (`uthmani.v2`) is a *matched pair* with Ver18 —
the ayah-number rosette and madd/tanwīn render through *this font's* GSUB. Swap to a non-KFGQPC
face → the rosette + madd break (high risk, different look). Other KFGQPC versions draw the waqf
the same way (no gain), and the Foundation CDN exposes no newer single-Unicode Hafs (only Ver18;
guessed newer names 404). The only path to the reference is the **QCF architecture** (PUA `code_v2`
text + per-page fonts + page layout) — a deliberate future project, not a tweak. **Decision: keep
Ver18 for v1 (correct + quran.com-Unicode parity); exact-Mushaf (QCF) is scheduled separately.**

---

## 2. QPC Quran text data specifics

- `text_arabic_uthmani` ends each ayah with an **end-of-ayah marker**: a space +
  **Arabic-Indic digits** (U+0660–U+0669), sometimes the U+06DD ornament. Strip
  it at **pipeline time** (in `prepare_sources.py`, via `text.rstrip(' ۝٠١٢٣٤٥٦٧٨٩')`)
  so the database contains clean text and the app never touches the strings.
- **Tatweel (U+0640) kashida carriers — the QUL word-by-word source omits them.**
  The canonical Uthmani edition carries 1652 tatweels as elongation carriers before
  superscript marks (madd `يَـٰٓ`, dagger-alef `ٱلصَّـٰلِحَٰت`, hamza `بِـَٔايَٰت`); the QUL
  word-by-word export has none, so the font collapses those marks. **Graft them in at
  pipeline time** by diffing our text against the canonical edition and copying only the
  tatweel runs (see `prepare_sources.py` `_transfer_tatweel`; full story in §1). This is
  one half of the fix — the other half is disabling Impeller so the marks anchor (§1).
- The text is dense with QPC annotation marks the font must cover: U+0670 (dagger
  alef), U+0671 (alef wasla), U+06D6/D7/D8/DA/DB/DC (small high waqf signs — all
  zero advance in KFGQPC, safe), U+06DD (end of ayah), U+06DE (rub el hizb star,
  advance 1273 — intentional inline marker), U+06E1 (rounded sukun, ~37k), U+06E2
  (small high meem — zero advance, safe), U+06E5/E6 (small waw/yeh — letter
  substitutes with smaller but non-zero advance, intentional), U+06E9 (sajda,
  advance 923 — intentional inline marker).
- **U+06ED and similar marks have +1442 advance in KFGQPC — strip them.**
  U+06ED (ARABIC SMALL LOW MEEM, 4 807×) and U+06E3/06EA/06EB (1× each) have
  `+1442` advance (≈ full letter width) in KFGQPC — they're Mn-class combining
  marks that *should* have zero advance but the font gives them full advance,
  causing visible gaps after tanween words and other positions where they appear.
  The AbdullahGhanem DB includes them (not present in the old QUL pipeline data).
  Strip all four in `normalize_uthmani()` in `convert_ghanem.py`. U+06DF (+large
  dashed circle) and U+06E0 (rectangular) are similarly problematic and already
  stripped. Diagnose with: `printf 'char' | hb-shape font.otf` — look for
  advance > 0 on any mark you suspect.
- **Better Arabic text source: `github.com/quran` — `quran.ar.uthmani.v2.db`.**
  The quran org (Apache 2.0) has two directly usable databases:
  `quran.ar.uthmani.v2.db` (authoritative Uthmani Arabic, 6236 ayahs, Bismillah
  pre-separated) and `quran.en.khanhilali.db` (Khan-Hilali English). Both use the
  QPC-native encoding: **U+06E1** for sukun (instead of U+0652), which our KFGQPC
  Hafs V18 supports and which triggers extra calligraphic ligatures (`Bism`, `Allah`).
  Much cleaner mark set: only 99× U+06ED vs 4807× in ghanem. Limitation: no Urdu
  translation and no page/juz/hizb metadata — still need ghanem for those. Also
  still requires tatweel normalization (V18 needs `ـٰٓ` carriers; the v2 text omits
  them, requiring `text.replace('ٰٓ', 'ـٰٓ')` at conversion time).
  Download: `gh api repos/quran/quran-ios/contents/Domain/QuranResources/Databases/quran.ar.uthmani.v2.db -H "Accept: application/vnd.github.raw"`.
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
- **IndoPak script: use the AUTHENTIC text (Quran.com `text_indopak`), normalised
  for Noorehuda — not a standard-Unicode substitute (2026-06-24).** The first IndoPak
  attempt rendered the `quran-simple-enhanced` (Tanzil) text in Noorehuda: it shaped
  with 0 `.notdef` but the *orthography was wrong* — the owner spotted it on al-Fatiha
  (iyyaka written `إِيَّاكَ` with a spurious hamza instead of bare `اِيَّاكَ`; maalik
  with a written-out alef instead of the dagger-alef `مٰلِكِ`; missing zer under the
  alef in ihdina). The fix is the genuine IndoPak text, which is authored for
  **PDMS_Saleem** and carries 1383 Private-Use-Area glyphs. Normalise it for Noorehuda
  (`build_indopak_source.py`): **map** the PUA marks that have a Unicode form
  (E003→U+0656 subscript-alef, E004→U+0657 inverted-damma) and the two letters
  Noorehuda spells the standard way (U+06AA swash-kaf→U+0643, U+06D2 yeh-barree→U+064A);
  **strip** the 7 IndoPak-specific waqf symbols that have NO Unicode form
  (E01A/E01B/E01C/E01E/E01F/E021/E022 — the ز ص ق ع-ruku family, ~1378×) plus zero-width
  /directional controls (200B–200F, FEFF, 0604). The *standard-Unicode* waqf marks
  (U+0615, U+06D6, U+06D9 …) are kept and render natively. Result: 0 `.notdef` across
  all 6236 ayahs AND correct letterforms. Quran.com serves each ayah WITHOUT a bundled
  basmala (`2:1 = الٓمّٓ`), so no basmala-strip step (unlike AlQuran-Cloud). Validate
  headlessly with uharfbuzz + the font's cmap (0 notdef + 0 uncovered codepoints), and
  pin the owner's flagged words as **codepoint canaries in `verify_db.py`** so the
  spelling can't silently regress. Lesson: "0 `.notdef`" only proves it *renders*, not
  that it's the *right text* — eyeball the orthography against a reference Mushaf.

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
- **Verse number INSIDE the ornament — SOLVED: just write the number as
  Arabic-Indic digits; the KFGQPC font draws the rosette around them.** In the
  KFGQPC HAFS face (both `UthmanicHafs1 Ver18` Regular and `1B Ver13` Bold) the
  ayah-number digits compose, via the font's own GSUB,
  into the ornate end-of-ayah medallion *with the number inside* — verified with
  `hb-shape` and `hb-view`: `١`→`_770`, `٢٣`→`a002_a003`, `٢٨٦`→`a002_a008_a006`,
  each a single full-em (advance 1700) rosette glyph. So the per-verse marker is
  simply `' ${_toArabicIndic(n)} '` appended in the surah paragraph (same font as
  the text, only the colour differs — the substitution won't fire across a
  *different-font* span). **Do NOT add U+06DD** — that draws a second, empty circle
  next to the numbered one (the long-misdiagnosed "two circles"). It's pure text:
  correct RTL order, continuous reflow, pinch-zoom, and copyable — none of the
  overlay/WidgetSpan machinery below is needed.
  > Two earlier "facts" were WRONG and sent us in circles: (a) "KFGQPC has no
  > single Arabic-Indic digit glyph (`٣`→`.notdef`)" — false for Ver13; the digits
  > map to numbered-rosette glyphs. (b) "the font renders `U+06DD`+digit as two
  > circles so the number can't go in the text" — the two circles were `U+06DD`
  > (circle 1) + the digit's own rosette glyph (circle 2); drop `U+06DD` and you get
  > exactly one. **Always confirm font shaping with `hb-shape`/`hb-view` before
  > concluding a glyph/ligature is impossible.**

  **Superseded approach (kept as the record of the dead-ends).** Before finding the
  native composition we proved an inline *widget* can't work and built a fragile
  overlay (which went invisible on-device twice). Three probe tests pinned the
  widget limits down:
  1. `WidgetSpan` medallions in a single RTL `Text.rich` are placed in *logical*
     (left-to-right) order, not bidi-reordered — verse 1's medallion lands leftmost.
     A *single self-contained* WidgetSpan still reverses (it's not the two-span split).
  2. Raw `dart:ui` `ParagraphBuilder.addPlaceholder` + `getBoxesForPlaceholders()`
     reverses **identically** — so this is an *engine*-level placeholder behaviour,
     not a framework/widget-layer bug. `CustomPaint`-from-placeholders is dead too.
  3. Only **real text** reorders correctly in RTL. So U+06DD (ARABIC END OF AYAH)
     stays in the text run as the anchor, giving correct order **and** continuous
     inline flow (one `Text.rich` per surah group → verse N+1 begins where N ended).
  **The number is then overlaid, centred, on the rosette:** U+06DD is purpose-built
  as a *number container* (that's why the font's GSUB tries — and fails — to compose
  `U+06DD + digit` into one glyph, producing the two-broken-circles bug). In a
  `Stack`, child[0] is the `Text.rich` (sits at the origin, so its `RenderParagraph`
  local space == Stack space); for each ayah, `getBoxesForSelection(offset, offset+1,
  boxHeightStyle: BoxHeightStyle.tight)` gives the rosette's box, and a
  `Positioned.fromRect` → `Center` → `FittedBox(scaleDown)` → `Text` paints the
  Arabic-Indic number inside it. **Use `BoxHeightStyle.tight`**: its box centre
  coincides with the *glyph* centre regardless of the paragraph's `height:` multiplier
  (a `max`/default box is the full line height, so a centred number floats in the
  leading). Re-measure in a `addPostFrameCallback` scheduled from `build()` with a
  *guarded* `setState` (only when a rect changes) so zoom/reflow/rotation re-anchor
  without an infinite loop. Graceful degradation: the rosette is always drawn (it's
  text), so even if a number nudges, nothing disappears — unlike a fully-drawn
  medallion overlay, which vanished entirely the one time its offset math drifted.
  **KFGQPC Arabic-Indic digits caveat:** KFGQPC has NO individual Arabic-Indic digit
  glyphs (U+0660–U+0669) — only 5 multi-char GSUB ligatures (`٠`, `١٢٣`, `٤٥`, `٦٧`,
  `٨٩`); a lone `٣` → `.notdef`. This is *fine for the overlay number* because it's a
  separate `Text` in the **platform font**, not KFGQPC — so Arabic-Indic numerals
  (the traditional Mushaf numeral, what Urdu/Hindi readers expect) render correctly.
  Earlier the digit had to be ASCII only because it lived in the KFGQPC paragraph.
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
- **Last-read resume to the *exact verse* — two viewports, two mechanisms.** The
  flowed Mushaf (one `Text.rich`) and the Detailed `ListView` need different
  scroll-to-verse tools:
  - *Flowed Mushaf (one `Text.rich` per surah group):* verses share a paragraph,
    so there are no per-verse anchor widgets. Place a `GlobalKey` on each group's
    `Text` widget and pre-compute each verse's **character offset** within its group
    (`_buildOffsets()`: iterate ayahs, accumulate `textArabic.length + marker.length`
    per verse). To get a verse's local Y from its char offset, use
    **`obj.getOffsetForCaret(TextPosition(offset: o), Rect.zero).dy`** —
    convert to scroll coordinates via `obj.localToGlobal(Offset.zero).dy -
    viewportBox.localToGlobal(Offset.zero).dy` and animate. Detect the topmost verse
    the same way: loop groups/verses, compare `groupGlobalY + caretY` to the viewport
    top, take the last one at/above the fold. Rebuild offsets in both `initState` and
    `didUpdateWidget` (when `ayahs` changes). `context.findRenderObject()` returns
    `RenderObject`, not `RenderBox` — cast before `localToGlobal`.
    > **DO NOT use `RenderParagraph.getBoxesForSelection(o, o+1)` for this** — it
    > returns an **EMPTY list for almost every offset in heavily-shaped Arabic text**
    > (only isolated glyphs like the U+06DD medallion or spaces box cleanly). Verified
    > on the iOS sim: offsets 0/100/1000/2000/3837 → 0 boxes, while `getOffsetForCaret`
    > returns a correct Y for all of them. Using `getBoxesForSelection` silently broke
    > focus-scroll, Last-Read resume, AND the font-size re-anchor (the functions bailed
    > on the empty list, so the scroll position drifted — to verse 1 on zoom-in,
    > "stays-ish" on zoom-out). **This is invisible to widget tests**: the test font
    > boxes every glyph (no real shaping), so `getBoxesForSelection` never returns empty
    > there — only a real-device render exposes it. Reproduce/diagnose with a throwaway
    > diag that opens the real reader at a deep verse and `debugPrint`s the boxes vs
    > caret for several offsets. (`getBoxesForSelection` is still fine where you need the
    > box *size* of an isolated glyph — e.g. the medallion overlay measuring U+06DD.)
  - *Detailed list:* a lazy `ListView.builder` can't `ensureVisible` an unbuilt
    tile, so use **`scrollable_positioned_list`** — `ItemScrollController.scrollTo(
    index:)` handles unbuilt items, and `ItemPositionsListener` gives the topmost
    visible index for free (map header rows → the next ayah row).
  - *Capture* the top verse on **scroll-idle** (debounce ~400ms; reuse the page
    pill's idle timer in Mushaf), persist it via the cubit. *Restore* in a
    post-frame callback in `initState`, and only for the **initial** section —
    clear the focus id on swipe so adjacent sections open at their top. A brief
    tint (TextSpan `backgroundColor` in Mushaf, `AnimatedContainer` color in
    Detailed) confirms "you are here".
- **Persisting reading prefs:** register `SharedPreferences` as a GetIt singleton
  loaded once at startup, expose it behind a repo with **synchronous getters**
  (so `State` can initialize `late` fields directly — no FutureBuilder flicker)
  and async setters. Fire setters with `unawaited(...)` (satisfies the
  `unawaited_futures` lint). For pinch-zoom, persist the **final** value on
  pointer-up, not on every move, to avoid write spam.
- **"Light of Day" — time-adaptive theming (the signature differentiator).** Instead of a
  light/dark flip, the reading surface follows the day: 5 hand-tuned palettes (`DayPhase`
  fajr→isha) in `mushaf_palette.dart`, each a full `MushafPalette` (surface/ink/accent/
  badge/gold) → `toTheme()` (M3 `ColorScheme.fromSeed(accent).copyWith(surface,onSurface,
  primary,primaryContainer)` + flat chrome). `ThemeCubit` emits a `ThemeState{palette,auto}`:
  in AUTO it resolves the phase from an injectable clock (re-ticks every 5 min + on app
  resume) or holds a fixed light; choice persisted under one key (`'auto'|DayPhase.name`).
  `app.dart` drives a SINGLE `theme:` (no darkTheme/themeMode) with `themeAnimationDuration:
  700ms` + `easeInOut` so the surface cross-fades ("breathes") between phases.
  - **Custom theme colours** (the ornament gold, with no `ColorScheme` slot) → a
    `ThemeExtension` (`MushafColors`): `toTheme()` adds `extensions:[MushafColors(gold:…)]`,
    read via `Theme.of(context).extension<MushafColors>()!.gold`. Implement `lerp` so it
    cross-fades with the theme animation.
  - **Gotcha — an auto ticker leaks in widget tests.** A `Timer.periodic` (the auto re-tick)
    is still pending at the pending-timer invariant check, which runs BEFORE `addTearDown`
    callbacks — so `addTearDown(cubit.close)` is too late and the test throws "A Timer is
    still pending". Fix: widget tests use a **fixed-phase** cubit (seed `theme_choice` to a
    `DayPhase.name`, no ticker); cover the auto LOGIC in pure (non-widget) cubit tests with an
    **injected clock**.
  - **Gotcha — `context.watch<Cubit>()` in `build` throws if the cubit isn't provided**, so a
    shared app-bar widget breaks every test that pumps a screen in isolation. Read it
    DEFENSIVELY (`try { BlocProvider.of<T>(context) } catch { null }`) + depend on
    `Theme.of(context)` for reactivity (the cubit drives the theme, so its value is current on
    the theme-triggered rebuild) — degrades gracefully and stays reactive.
  - **Gotcha:** any *hardcoded* text colour is invisible on the other surfaces — let text
    inherit `onSurface`; audit `grep "Color(0xFF"` outside the theme files.
- **Centralize the Arabic style** once (`QuranTextStyle.madani`) and
  `.copyWith(fontSize: …)` at call sites — avoids drift across widgets.
- **RTL text still left-aligns inside a `Column`.** A `Text` with
  `textDirection: rtl` in a `Column(crossAxisAlignment: start)` shrink-wraps and
  sits at the *left* edge (short Urdu lines look left-aligned). Fix: stretch the
  column (`crossAxisAlignment: stretch`) so each `Text` fills the width, then set
  `textAlign` per script (Arabic/Urdu → `right`, English → `left`). Direction
  alone is not alignment.
- **Urdu needs a Nastaliq font.** The platform default renders Urdu poorly. Bundle
  **Noto Nastaliq Urdu** (Google, SIL OFL — license-clean) with extra line height
  (~2.0). Jameel Noori Nastaleeq looks great but its licence is murky.
- **Icon gotcha:** `Icons.translate` shows a 文/A glyph that reads as "Chinese";
  prefer `Icons.subject` / `Icons.menu_book` for a reading/translation toggle.
- **A "premium" top bar = less, flatter.** Crowding 5 icons (theme, view, A−, A+,
  back) into the app bar reads as utilitarian. Move secondary controls into a
  single settings **bottom sheet** (`SegmentedButton` for theme/view, a `Slider`
  for text size, driving the page live via callbacks; reach the app-root
  `ThemeCubit` from the sheet with `BlocProvider.value`) behind one `Icons.tune`
  button. Make the bar blend into the page via an `AppBarTheme` with
  `elevation: 0`, `scrolledUnderElevation: 0`, `surfaceTintColor: transparent`,
  `backgroundColor = scaffold`, `centerTitle: true` — drops the Material "slab".
- **Chapter header as the hero moment.** Show the Arabic surah name in the QPC
  face (accent-coloured), the English name in a **display serif** bundled just for
  Latin headings (Playfair Display, SIL OFL — set via one `AppTheme.displayFontFamily`
  constant so it's swappable), and a muted "<revelation> · <n> verses" meta line.
  All the data (`name_arabic`, `revelation_place`, `total_ayahs`) was already in
  the `surahs` table — widen the `SurahHeading` entity, no schema/DB change.
- **One icon family, one catalog — the "pro" iconography fix.** The grab-bag of
  stock `Icons.*` variants (mixed `_rounded` / `_outlined` / filled / bare, sizes
  11–30) is what reads as unpolished. Standardised on **Material Symbols Rounded**
  (`material_symbols_icons`) behind a single `core/theme/app_icons.dart`:
  `AppIcons` (semantic name → glyph), `AppIconSize` (a fixed 14/16/18/22/24/30
  scale), and an `AppIcon` wrapper that bakes in one weight/grade and exposes
  `filled`. Every call site goes through `AppIcon` — no raw `Icons.`/`Symbols.`
  in feature code, so the look stays consistent and is changeable in one file.
- **Material Symbols gotchas (package `material_symbols_icons` 4.x):**
  `Symbols.name` (no suffix) is the *Outlined* face; the **Rounded** one is
  `Symbols.name_rounded` — reference only `_rounded` so release builds tree-shake
  the Outlined/Sharp fonts away entirely (the app stays light). Fill is the
  variable-font **FILL axis**, applied at the *widget* (`Icon(fill: 1)`), NOT a
  different IconData — so `find.byIcon(glyph)` matches regardless of fill, and the
  `active=filled / inactive=outlined` convention (reminders bell, Last-Read
  bookmark, status chips, Maghrib's golden dusk) is one glyph + a flag, not two
  icon names. `Icon` also takes `weight`/`grade`/`opticalSize` (Flutter ≥3.16);
  set `opticalSize ≈ size` (clamped to the 20–48 axis) for crisp small icons.
- **Tests that assert on icons must move with the catalog.** `find.byIcon(...)`
  pins the exact `IconData`, so swapping families breaks any test that named the
  old glyph (we had 5: theme-toggle, ayah-tile, ayah-tile-audio, home-page,
  next-prayer-pill). Point them at the `AppIcons.*` constant — one source of truth
  for both app and tests.
- **OPEN (paused 2026-06-27) — iOS renders some Material Symbols wrong, Android
  fine.** On the iOS sim (Impeller OFF / Skia) the Light-of-Day phase icon and the
  salat-row weather glyph look old/wrong while Android shows the new ones. Ruled
  out: `flutter clean`, fresh pods, removed Xcode `DerivedData/Runner-*`,
  delete-app + rerun; and debug `flutter run` doesn't tree-shake icons, so that's
  not it either. Next to try: confirm it isn't just a *clock/phase* difference
  (force the same phase on both via the reading-light sheet); check the
  MaterialIcons↔MaterialSymbols **codepoint collision** for weather glyphs
  (`wb_twilight`=0xe1c6, `light_mode`, `dark_mode`, `wb_sunny`); build a one-shot
  on-device icon grid (§6 method) and test a **release** build. Full details in
  Claude memory `ios-material-symbols-render-issue`.
- **Reading position must survive any *same-section reload*, not just a font
  change.** MushafView keeps your verse on a font change by capturing the topmost
  ayah pre-relayout and re-anchoring after (`didUpdateWidget`). The trap: a
  **script switch** (Uthmani⇄IndoPak) reloads the *same* verses in a
  longer/shorter face — a new `ayahs` list, same ids — and that branch only
  rebuilt, never re-anchored, so the reader drifted back ~15 verses (Last Read
  too: repro 18→3). Fix: re-anchor on the ayah-list branch as well. Why it's
  always safe — `didUpdateWidget` fires only on a *reuse* (same widget key =
  `ValueKey(first ayah id)` = same section); real section nav changes the key →
  fresh `initState`. So "ayahs changed in `didUpdateWidget`" ⟹ same section
  reloaded ⟹ re-anchoring is always correct. The SAME class also bit the Detailed
  view: `_DetailedList` built its flattened header/ayah rows only in `initState`
  and had no `didUpdateWidget` at all, so a script switch left the rows — and the
  rendered text — stale (old script's text in the new face). Lesson: **every
  reader widget that derives state from `widget.ayahs` must handle a same-section
  reload**, not just first build + section navigation.
- **No O(n) + fresh allocation in a scroll listener or per build.** The Mushaf
  flow re-ran `groupAyahsBySurah` O(n) on every build and `pageAtFraction`
  allocated an n-length list + scanned it on *every scroll frame* (286-ayah
  surah × 120 fps = real CPU + GC churn on low-end devices). Memoise anything
  derived purely from `widget.ayahs` (the surah groups, cumulative text lengths)
  and recompute only when the list changes; the page readout then becomes an
  O(log n) binary search with no per-frame garbage.
- **Measure on a physical device in profile, and beware the screen dozing.**
  `flutter test --profile` doesn't exist; profile mode won't run on an iOS
  *simulator* at all. Use `flutter drive --driver=test_driver/integration_test.dart
  --target=test_perf/reader_perf_test.dart --profile -d <device>` (`make perf
  DEVICE=<id>`). Collect frames with `SchedulerBinding.addTimingsCallback`
  (raw `FrameTiming`, no VM service) — **not** `binding.watchPerformance`, whose
  VM-service timeline can't connect under `flutter drive --profile` (SocketException).
  Two days lost to a red herring: the run kept dying at `+0` with "Service has
  disappeared" — it was the **device screen sleeping during the ~40s Gradle build**
  (`adb logcat` showed `surface=NULL` / window `GONE` at launch), not a crash. Keep
  it awake: `adb shell svc power stayon true` + periodic `input keyevent
  KEYCODE_WAKEUP`; a secured keyguard can't be bypassed (`wm dismiss-keyguard`
  only opens a non-secure lock). The benchmark lives in `test_perf/`, **not**
  `integration_test/`: `patrol test` regenerates `test_bundle.dart` from every
  `*_test.dart` there, and a plain `IntegrationTestWidgetsFlutterBinding` test
  would clash with `PatrolBinding`. Target the **PageView** for gestures, not
  `MushafView` — the PageView keeps neighbour sections built, so `find.byType
  (MushafView)` is ambiguous.
- **The reader's cost is all UI-thread *build*, never raster.** On a OnePlus
  (120 Hz → 8.3 ms budget) over Al-Baqarah (286 verses), GPU raster stayed ~2–3 ms
  everywhere; every spike was the build thread reshaping/​re-measuring the one
  continuous-Mushaf paragraph. Three measured hot spots and what helped:
  (1) **scroll** — the `_MarkedParagraph` re-measured all 286 verse-number
  medallions (`getBoxesForSelection ×286`) after *every* build, incl. each
  page-pill scroll tick. Gate it: cache the paragraph's `size` and skip the box
  scan when it hasn't changed (boxes only move on a reflow, which changes the
  size — covers rotation; reset the cache on a group change). Build p50 7.6→4.2 ms,
  frames over-8 ms 38%→20%.
  (2) **pinch** — `_setFont` took a *continuous* fractional size on every move, so
  one pinch fired dozens of full 286-verse reshapes (build frames to ~390 ms).
  Snap to whole points (`roundToDouble()`; the size slider was already 2 pt) — one
  reshape per 1 pt crossing. Helps real, gradual pinches a lot; a synthetic
  fast-zoom benchmark still reshapes each step.
  (3) **swipe** — p50 0.4 ms when the neighbour is pre-built; a *cold* section
  costs one ~148 ms first build. Inherent to constructing a surah.
  Residual pinch/swipe cost is **architectural**: continuous flow = one *non-lazy*
  paragraph, so every reshape lays out all 286 verses. The only true cure is not
  reshaping during the gesture (`Transform.scale` the laid-out text, reshape on
  release) — deferred, because text doesn't scale linearly with font size, so line
  breaks "snap" on commit.

---

## 4. Flutter project & build mechanics

- **Drift:** run `dart run build_runner build` before `flutter analyze`, or it
  errors on missing `*.g.dart`. With a prepopulated asset DB, keep
  `migration.onCreate` a **no-op** (tables already exist); set
  `case_from_dart_to_sql: snake_case` in `build.yaml` so camelCase getters map to
  snake_case columns.
- **Platform folders** (`android/`, `ios/`) are now **committed** (since 2026-06,
  when home-screen widgets landed — a WidgetKit extension / Android receiver must
  live in version control). The granular per-folder `.gitignore`s keep build
  artifacts out (patch the `android/.kotlin/` gap they miss). The unused
  desktop/web runners are still `flutter create`-generated and stay ignored.
- **Font/asset changes need a full rebuild** (hot reload won't pick them up).
- **Prepopulated/bundled SQLite updates are ignored after first launch.** The
  copy-once pattern (`if (!await file.exists()) copyAsset()`) means shipping an
  updated DB (typo fixes, new translations) never reaches users who already ran
  the app. Fix with a **version-aware reseed**: bundle a tiny version marker
  (here `assets/db/quran.db.version` = `db_meta.built_at`), store the last-seeded
  value in SharedPreferences, and re-copy when they differ — cheap at runtime
  (reads a ~30-byte asset, not the whole DB). Do the seeding in DI startup
  *before* opening the DB, and pass the file into the DB class. Remember to
  regenerate the marker whenever the DB changes (a `make seed-version` target).
- **Adding a native plugin needs a full rebuild, not hot reload.** After
  `flutter pub add share_plus`, a hot reload/restart reuses the existing native
  binary → `MissingPluginException(No implementation found for method … on
  channel …)` at runtime. Fix: full `flutter run` (or `flutter clean && flutter
  pub get && flutter run`) so `pod install` runs and `GeneratedPluginRegistrant`
  picks up the plugin. Verify with `grep <plugin> ios/Runner/GeneratedPluginRegistrant.m`
  and `ios/Podfile.lock`. Also wrap plugin calls (share/clipboard) in try/catch
  so a missing/again-failing plugin shows a snackbar instead of an unhandled
  exception. Diagnose runtime errors from a sim via
  `xcrun simctl spawn booted log show --last 4m | grep -i exception`.
- **GetIt "not registered" after a UI change = you hot-reloaded a DI change.**
  Adding a `getIt.register…` in `configureDependencies` and a `GetIt.I<X>()` use
  in the same change: hot reload (`r`) re-runs `build()` (which now needs `X`) but
  NOT `main()`/`configureDependencies()` (which registers it) → red-screen "X is
  not registered." Fix: hot **restart** (`R`) or rerun. No production impact (no
  hot reload there); it only bites during dev. Rule: DI graph changes need a
  restart, not a reload.
- **"Const class cannot remove fields … Try a hot restart" = you changed a
  widget's field layout.** Adding/removing a field on a (esp. `const`) class —
  e.g. dropping `NextPrayerPill`'s `compact` flag — alters the class shape, which
  hot reload (`r`) can't patch in place; it aborts with that message. Same family
  as the DI gotcha: structural changes need a hot **restart** (`R`), not a reload.
  Not a code error — analyze/tests stay green.
- **"No top-level method 'X' declared" at runtime = you MOVED a top-level
  function between libraries and hot-reloaded.** Hot reload patches each library
  in place; it doesn't track a top-level `X` migrating from file A to file B, so
  the caller can't find it and its `build()` throws — which then *cascades* into a
  nonsense layout error (e.g. "RenderFlex overflowed by 99687 pixels" as an
  ErrorWidget fills a sheet). Both vanish on hot **restart** (`R`). Tell-tale: a
  clean `flutter analyze` (the symbol resolves in a real build) + the second error
  being secondary ("Another exception was thrown: …"). Same restart-not-reload
  family as the const-class and DI gotchas.
- **`native_assets … references objective_c` build error** after clearing caches
  → fix with `flutter clean && flutter pub get`.
- **First APK build after adding a native plugin can fail in `:app:mergeExtDexDebug`**
  with *"property 'fileDependencyDexDir' specifies directory
  '…/desugarDebugFileDependencies' which doesn't exist"*. It's an AGP
  strict-input-validation flake over stale `build/` intermediates (the new plugin's
  file/AAR dependency introduces a desugar step that wasn't there before), NOT a
  code error — it fires at dex-merge, *after* Kotlin compile + AAPT succeed, and
  `flutter analyze` stays green. Fix: `flutter clean`, then rebuild. Seen right
  after `flutter pub add home_widget`.
- **`flutter build … | tee | tail` hides the real exit code.** A piped build
  reports the pipeline's last command's status (the `tail`), so a FAILED Gradle
  build looks like exit 0. Capture `${PIPESTATUS[0]}`, or redirect to a file and
  check `$?` directly, when you actually care whether the build passed.
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

## 5. Prayer times — offline calc + a prayer-aware theme

- **Compute on-device with `adhan` (pure Dart) — no backend, fits the offline
  ethos.** `PrayerTimes(Coordinates(lat,lon), DateComponents.from(date),
  params, utcOffset: …)` where `params = CalculationMethod.muslim_world_league
  .getParameters()..madhab = Madhab.shafi`. The six getters
  (`fajr/sunrise/dhuhr/asr/maghrib/isha`) are non-null `late DateTime`.
- **`utcOffset` makes the wall-clock fields right — but its DateTimes lie about
  the instant.** Pass `date.timeZoneOffset` (the user is physically at the GPS
  location, so the device offset is right, DST included); in tests a
  `DateTime.utc(...)` → offset 0 → deterministic UTC-clock fields you can assert
  to the minute. **The trap:** with `utcOffset` set, adhan returns each time as
  `t.toUtc().add(offset)` — a DateTime flagged `isUtc` whose *fields* show the
  correct local time but whose *instant* is shifted by the offset. So
  `time.isAfter(DateTime.now())` is off by the offset: in IST (+5:30) an
  afternoon Asr still read as "after" a 9pm `now`, so the pill showed a
  long-passed prayer as next instead of rolling to tomorrow's Fajr. **Fix:**
  normalize at the data boundary — rebuild a plain local DateTime from the
  wall-clock fields (`DateTime(t.year, t.month, t.day, t.hour, t.minute)`):
  identical display, correct instant, `isUtc == false`. Display worked all
  along, which is why it slipped past the first tests — the regression test now
  asserts the times are non-UTC and that one minute past Isha `nextAfter()` is
  null. (Comparisons over these times — the creed guard, ordering checks — must
  be representation-agnostic too: compare time-of-day, not instants, or both
  operands must be normalized the same way.)
- **Encode a creed constraint as code, never as a setting.** The owner follows
  Salafi/Ahle-Hadith: Standard (Shafi) Asr, Hanafi never offered. So `_method`
  and `_madhab` are the *only* two calc constants, hard-wired in the repo and
  never surfaced in any UI. Guard it with a **regression test that computes the
  Hanafi Asr alongside and asserts ours is earlier** — a refactor can't silently
  flip the creed without going red.
- **Calculation method is regional, not creedal — pick it for the audience.**
  The *method* sets only the Fajr/Isha twilight angles; Asr is method-independent
  (it follows the madhab's shadow ratio). So the method is free to track the
  user base: this app's Urdu/Hindi audience is subcontinental, where the standard
  is **University of Islamic Sciences, Karachi** (18°/18°). We started on MWL
  (17° Isha) and it ran ~6 min early vs the owner's local Delhi reference;
  Karachi matched every prayer to the minute. Verify a method against a trusted
  local source before hard-wiring it — the angles diverge most at Isha/Fajr.
- **Keep `adhan`/`geolocator` out of `domain/`.** Domain owns a plain `Prayer`
  enum + a `LocationProvider` interface; the data layer maps the package types
  to domain types. The cubit depends on the repo interface, so it tests with a
  fake repo and no GPS.
- **Core must not import a feature — pass primitives across the seam.** The
  "Light of Day" theme lives in `core/theme`; the prayer schedule lives in a
  feature. So `core/theme/prayer_phase.dart` exposes
  `phaseForBoundaries({fajr, sunrise, asr, maghrib, isha, now})` taking bare
  `DateTime`s, and `ThemeCubit` gains an **optional** `phaseResolver` closure.
  The DI graph (which may see both layers) wires the closure to read the prayer
  repo, falling back to `phaseForHour` when no location is known. Optional +
  defaulted params kept all 16 existing theme tests green byte-for-byte.
- **A static indicator needs no `Timer` — so it can't leak or drain.** The pill
  shows the *next* prayer, not a live countdown; the cubit recomputes only on
  `refresh()` (app-resume + the theme's existing tick). Contrast the auto-theme
  ticker, whose pending timer trips the widget-test invariant.
- **Read the cubit defensively in shared app-bar widgets.** `NextPrayerPill`
  does `try { BlocProvider.of<…>(context) } catch (_) { null }` →
  `SizedBox.shrink()`, so a screen pumped in isolation (no provider) renders
  nothing instead of throwing — same trick as `ThemeToggleButton`.
- **Native location perms are gitignored — make re-applying them one command.**
  `ACCESS_COARSE/FINE_LOCATION` (AndroidManifest) and
  `NSLocationWhenInUseUsageDescription` (Info.plist) live under `android/`/`ios/`,
  which `flutter create` regenerates. `make location-perms`
  (`tool/apply_location_perms.py`) idempotently re-inserts both — run it after
  any platform regen, like `make patch-font` for the font.
- **Two modal-bottom-sheet bugs that ONLY surface in widget tests** (a reason to
  keep them): (1) a `Column` whose rows use `Row` + `Spacer` must be
  `crossAxisAlignment.stretch` — a `MainAxisSize.min` column doesn't bound the
  row's width, so `Spacer` has unbounded width → "content cannot be laid out".
  (2) The default sheet height cap (~half screen) overflows the 800×600 test
  surface → set `isScrollControlled: true` so the sheet sizes to its (small,
  fixed) content. Both render fine on a real phone but fail the test harness.
- **Forbidden-prayer windows: derive what the lib won't give you, and be honest
  about the rest.** The three times prayer is prohibited (after sunrise, zenith,
  before sunset) need the sun's elevation, which `adhan` doesn't expose. Two of
  the three boundaries are still computable exactly: the **zenith** window
  anchors on real solar noon = midpoint(sunrise, sunset), and since Maghrib *is*
  sunset, `solarNoon = sunrise + (maghrib - sunrise)/2`; it ends at Dhuhr
  (zawāl). The "spear's length" after sunrise and the yellowing before sunset
  fall back to documented ~15-min constants — name them, don't bury them, and
  drop any degenerate span (`start >= end`) so odd inputs can't render a
  backwards window. Compute the *active* window from TODAY's schedule **before**
  any after-Isha rollover swaps the day for tomorrow.
- **Reuse the palette's semantic extension for a new accent instead of a hard
  colour.** A caution amber that had to read on five hand-tuned surfaces (incl.
  the dark night) would need five values — but `MushafColors.gold` already is
  that, phase-tuned, and a golden cue suits the sun-at-the-horizon meaning.
  Read theme extensions **defensively** (`Theme.of(context).extension<…>()?.x ??
  fallback`): bare test themes (plain `MaterialApp`) don't carry them, so a
  non-null assertion would crash every widget test that pumps the screen alone.
- **Hijri date: the Islamic day begins at SUNSET, not midnight.** A calculated
  Hijri date must roll to the next day once Maghrib has passed — and we already
  have Maghrib, so it's a free, knowledgeable touch. Subtlety: compute it from
  **today's civil Maghrib**, not the next-prayer schedule (which after Isha has
  already rolled to *tomorrow's* day) — otherwise late evening you'd lose the
  +1. Show the Gregorian line as the civil (phone) date; the Hijri being one
  ahead after Maghrib is correct, not a bug.
- **Hijri conversion needs no package — and no settings screen for the ± fix.**
  The integer **Kuwaiti tabular algorithm** (Gregorian→JDN→Islamic) is ~25 lines
  of pure Dart, deterministic and offline; anchor a test on a known pair
  (`2000-01-01 → 24 Ramadan 1420`). The tabular calendar differs from a local
  moon-sighting by up to a day, so a **± day adjustment** (offset the input date)
  is tempting — but a *bare* inline ± control read as unexplained clutter to the
  owner ("what's that +/- signs?") and got pulled. Lesson: don't surface a raw
  nudge with no label/context; if a correction is needed, give it a clear home
  (a labelled setting) or skip it and flag the calc-vs-sighting gap in words. The
  shipped form is plain English ("07 Muharram 1448 AH"). (If you DO render Urdu —
  e.g. the companion website — use **Urdu-Indic digits (U+06F0)**, never
  Arabic-Indic (U+0660); same digit split as the Mushaf numerals.)
- **Islamic reminders with local notifications only — no backend, no Hijri
  inverse.** Find Hijri-dated events (Ashura, Arafah, Ayyam al-Bid…) by
  **forward-scanning Gregorian days** through the existing `HijriDate.fromGregorian`
  (Gregorian→Hijri only) and matching month/day — a pure, testable engine like
  `DailyPrayerTimes`, no new calendar engine. Scheduling reliability comes from a
  **rolling window**: `cancelAll()` + reschedule the next ~50 one-shots on every
  app launch/resume, so far-future months roll in and you stay under **iOS's
  64-pending-notification cap**. Use **`AndroidScheduleMode.inexactAllowWhileIdle`**
  (a 20:00 reminder doesn't need second-accuracy) to AVOID the
  `SCHEDULE_EXACT_ALARM` special-access prompt. Register one **weekly-repeating**
  notification for recurring events (Al-Kahf via `DateTimeComponents.dayOfWeekAndTime`)
  rather than enumerating every week. FLN boot receivers re-arm after a reboot;
  the gitignored native config (POST_NOTIFICATIONS + receivers) re-applies via
  `make notif-perms` (mirrors `make location-perms`).
- **Package-version gotchas (current as of FLN 22 / flutter_timezone 5):**
  `initialize({required settings: …})` is now NAMED (was positional);
  `FlutterTimezone.getLocalTimezone()` returns a `TimezoneInfo` (use
  `.identifier`), not a `String`; and `tz.setLocalLocation(...)` MUST run before
  any `zonedSchedule` — do it in `main()` after DI, wrapped in try/catch with a
  UTC fallback so a timezone lookup can't block launch. Always re-check a plugin's
  current signatures against the resolved version (`pubspec.lock`), not the docs.
- **iOS drops FOREGROUND local notifications unless you set the notification
  delegate.** A `show()`/`zonedSchedule` that fires while the app is open shows
  nothing on iOS until `UNUserNotificationCenter.current().delegate` is set (so
  the plugin's `willPresentNotification` runs) — `flutter_local_notifications`
  does NOT set it itself; the app must, in `AppDelegate.swift`
  (`if #available(iOS 10.0,*){ UNUserNotificationCenter.current().delegate = self }`
  + `import UserNotifications`). `FlutterAppDelegate` conforms to the delegate and
  forwards to FLN. This bit a "send a test reminder" button (fires foreground) on
  the iOS sim while real evening reminders (delivered backgrounded) worked fine —
  background delivery needs no delegate, foreground presentation does. The
  `defaultPresentBanner/Alert/Sound` init flags already default to `true`, so it's
  the delegate, not the present flags. `ios/` is gitignored → re-applied by
  `make notif-perms` (`tool/apply_notification_config.py`), like the Android receivers.

---

## 6. Methodology meta-learnings

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

## 7. Licensing (clear before any release)
- **KFGQPC** fonts: licence UNVERIFIED — the King Fahd Complex terms must be
  confirmed for redistribution in an app store build.
- **Noto Nastaliq Urdu:** SIL OFL 1.1 — clean.
- Translations (Junagarhi Urdu, al-Umari Hindi) and any audio: verify separately.
