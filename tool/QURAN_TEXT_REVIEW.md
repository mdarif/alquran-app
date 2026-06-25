# Qur'an Text Review — verification notes & fix log

Running log of verifying the bundled Arabic matn and aligning our rendering with
**quran.com** (the authoritative display the owner trusts). We review chapter by
chapter, log issues here, and apply fixes **consolidated across the whole Qur'an
at the end** (not piecemeal).

## Method

- **Layer A — integrity (offline, exact).** Our `ayahs.text_arabic_uthmani` vs the
  golden KFGQPC source `../alquran-data/sources/quran.ar.uthmani.v2.db`
  (table `arabic_text`). Must match byte-for-byte after stripping kashida. Proves
  the build pipeline didn't corrupt anything. **Result: exact, all 6236 ayahs.**
- **Layer B — vs quran.com (the displayed text).** Our text vs quran.com's
  **`text_qpc_hafs`** field — the QPC Hafs script the **website actually renders**.
  - ⚠️ NOT `text_uthmani`: that's a *different*, plainer Tanzil-style digitization
    the site never displays. Comparing against it produced hundreds of false
    differences (sukūn glyph, tanwīn glyphs, etc.). `text_qpc_hafs` matches our
    source. Fetch via `…/verses/by_chapter/{n}?fields=text_qpc_hafs` (paginated).
- **Tools** (in `tool/`):
  - `verify_uthmani.py` — per-surah pass/fail (Layer A + B), letter vs mark diffs.
  - `visual_diff.py` — rendered **HTML** diff in the app font; highlights only
    reading-level differences (`uthmani_diff_<n>.html`).
  - `sweep_uthmani.py` — all-114 categorised sweep → `.cache/sweep_results.json`.

## Findings — Uthmani

### 1. Kashida over-graft — PRIMARY, systematic  [TO FIX]
- Our build grafts **1,117 extra kashida (U+0640) carriers across 939 ayahs** vs
  the clean text (golden source **535** = quran.com **535**; ours **1,652**).
- They cause a visible **over-stretch**, e.g.
  - 2:43  `ٱلرَّـٰكِعِينَ`  (clean: `ٱلرَّٰكِعِينَ`)
  - 2:222 `ٱلتَّوَّـٰبِينَ` (clean: `ٱلتَّوَّٰبِينَ`)
  - 2:72  (kashida + the hamza spot below)
- quran.com renders the **clean** 535-kashida text correctly — the extra grafts
  aren't needed for correct shaping in the browser.
- **Root cause:** `../alquran-data/pipeline/build_db.py` → `graft_tatweel_carriers()`
  (grafts kashidas from the Tanzil reference). Added originally because Flutter
  (Impeller/Skia) didn't anchor the elongated madd (يَـٰٓ) on bare letters.
- **⚠️ Caveat before removing:** there is a font patch `tool/patch_arabic_font.py`
  (KFGQPC GPOS madd anchors). If the **patched font** renders the clean text
  correctly **in Flutter**, the graft is unnecessary. Must be **verified on device**
  before we drop it — the browser (HTML diff) is not proof of Flutter behaviour.

### 2. Two notational encoding spots — minor  [optional align]
The **only 2 reading-level differences in all 6,236 ayahs**. Both are notation
(same recitation), and in both **ours matches the KFGQPC source**:
- **2:72** فَٱدَّٰرَٰٔتُمۡ — medial hamza as a **combining mark** (ours) vs a
  **standalone ء + sukūn** (quran.com).
- **11:41** مَجۡر۪ىٰهَا — the **imāla** marker on the ر: **U+065C** dot-below (ours)
  vs **U+06EA** empty-circle-below (quran.com).

### 3. IndoPak — REVIEWED  [no graft issue; normalisation is correct]
Swept all 114 vs quran.com `text_indopak` (`tool/sweep_indopak.py`):
- **0 extra kashidas** — IndoPak does **not** have the Uthmani graft problem; its
  3,502 kashidas match quran.com (native IndoPak orthography).
- All differences are **intentional Noorehuda normalisation**, no matn errors:
  - **PUA glyph codes** (U+E01A–E022) removed — quran.com's IndoPak-font glyph
    codes that would be `.notdef` in Noorehuda (the "0 .notdef" normalisation). ✓
  - **Invisible spacing** (U+200B ZWS, U+2002 EN SPACE) normalised to plain spaces.
  - **2 letter-FORM maps across the whole Qur'an** (17 spots): swash-kaf ڪ→ك (16×)
    and yeh-barree ے→ي (1×, 4:84). Same letters/reading; mapped for the font.
- **No fix needed.** Optional only: restore ڪ/ے *if* Noorehuda has those glyphs
  (calligraphic nicety — verify font coverage first).

## Fix plan — consolidated, applied across the whole Qur'an at the end
1. **Source of truth.** Cleanest: adopt quran.com **`text_qpc_hafs`** as our
   Uthmani text — clean, matches the website, and resolves all three issues at
   once (kashida + 2:72 + 11:41). Alternative: drop the graft in `build_db.py`
   (keep golden as source) and hand-align the 2 spots.
2. Rebuild `quran.db` in `../alquran-data`; update `pipeline/verify_db.py`
   sentinels — `EXPECTED_TATWEELS = 1652` and the 5:1 `يَـٰٓ` canary **will change**.
3. **Verify Flutter rendering on device** with the patched font: the madd/marks
   must still seat correctly without the extra kashidas. (Owner runs the app.)
4. Re-seed the app: replace `assets/db/quran.db`, run `make seed-version`.
5. **IndoPak: no change needed** (reviewed — normalisation is correct).

## Sweep results (Uthmani vs quran.com `text_qpc_hafs`)
- Machine output: `tool/.cache/sweep_results.json` (per-surah counts).
- **Totals:** 1,117 extra kashidas across **939 ayahs**; **2** reading-level diffs
  total → **2:72**, **11:41**.
- **No genuine matn errors found anywhere** — every difference is the kashida
  graft, an invisible encoding (space / mark-order), or one of the 2 notation spots.

## Status log
- **2026-06-25**
  - Corrected the reference: `text_uthmani` → `text_qpc_hafs` (what quran.com shows).
  - Surahs 1–3 reviewed in detail; full 114-surah sweep complete.
  - Confirmed: matn is faithful (Layer A exact); the only systematic divergence
    from quran.com is the kashida over-graft (cosmetic stretch), plus 2 notation
    spots. Fixes deferred to the consolidated pass.
  - IndoPak swept (all 114): no graft issue, normalisation correct, no fix needed.
  - TODO next: decide Uthmani fix approach (#1 above), execute in ../alquran-data,
    verify madd rendering on device, re-seed.
