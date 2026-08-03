# Madani Mushaf page mode — implementation plan

**Status:** proposed, not started · **Owner ask:** 2026-08-02 · **Roadmap:** #2
(product-backlog.md) · **Scope:** the Flutter app only — **explicitly not the
website** (owner decision; app↔web parity does not mean exact replica).

Reference apps:

| App | Text | Zoom | Verse tap |
|---|---|---|---|
| KFGQPC "Quran Hafs" / مصحف المدينة | page-faithful | **yes** | yes |
| Al Quran (Greentech), Madani Mushaf 1440 | page-faithful, **selectable** | no | yes → translations + actions |
| Quran.com native | page-faithful, selectable | no | yes |

Target: the attached page 77 (Surat an-Nisa opening) — decorative frame, surah
title band, `الجزء الرابع` / `سورة النساء` running heads, 15 justified lines,
Arabic-Indic page number at the foot — **with** zoom, which only KFGQPC offers,
**and** selectable/tappable verses, which Greentech and Quran.com prove is
compatible with page fidelity. Nobody in the table has both. We should.

---

## 1. The framing decision: this is a *viewport*, not a *script*

The single most important call, and the one that makes or breaks the estimate.

`ArabicScript { uthmani, indopak }` is a **text** choice — a different column in
`quran.db` rendered by our flowing paragraph layout. The Madani Mushaf is not
that. It is a **fixed 604-page canvas** where the app does not lay out text
freely; the page is the atom and the line breaks are given.

So it does **not** extend `ArabicScript`. It becomes a third viewport beside
Reading and Detailed:

```
ReaderViewport { reading, detailed, mushafPage }
```

Consequences to accept up front rather than discover in week three:

- **No reflow, therefore no font-size slider.** The 15-line page cannot respond
  to `arabicFontSize`. Text size is *zoom* — which is exactly the gap the owner
  spotted in Greentech and Quran.com. The PRD pinch-to-zoom accessibility
  requirement is met by zoom, not by the +/- buttons; those hide here.
- **No translations printed on the page.** There is no room. Translations are
  reached by **tapping a verse** (§7) — the Greentech/Quran.com model, and close
  to what our Detailed view already shows. Detailed view itself is untouched.
- **Navigation becomes page-first.** Surah/juz still enter the mode, but they
  resolve to a page number and it pages horizontally from there.
- **`MushafView` is not reused.** It is our flowing lazy-list renderer and stays
  as-is for Reading. The new widget is a sibling; they share nothing but a name.

---

## 2. How the page is actually built: **fonts on top of an image frame**

This went through two wrong drafts before landing; the resolution reconciles all
the evidence, so both dead ends are recorded here to stop anyone re-walking them.

**The evidence:**

- Greentech's Madani Mushaf 1440 and Quran.com have **selectable** verses. You
  cannot select a picture. There is a real text layer.
- The KFGQPC page has **pink waqf marks, blue rosettes and a polychrome floral
  frame**. I earlier read that as proof of a page image. It is not: the QPC page
  fonts are addressed by **per-word glyph codes**, so the app renders each word
  as its own span and can colour spans independently — a waqf sign and an ayah
  rosette are their own glyph codes and can be pink and blue. Colour is a
  *rendering* choice, not evidence of an image.
- The **frame** genuinely is artwork. No font produces that. But it is *one
  asset behind the text*, not 604 page pictures.
- In the reference app **every colour on the page is configurable** (owner,
  exploring it 2026-08-02). That **rules out raster images entirely** — you
  cannot recolour a PNG per element. It does *not* choose between SVG and fonts:
  per-word glyph codes rendered as spans recolour just as freely, which is
  exactly how you expose "body text / waqf marks / ayah markers" as separate
  colour settings. The only thing it settles beyond raster is the **frame**: if
  its greens and pinks are configurable too, the frame is **vector, so ship it
  as SVG, not WebP** (§6).

**The build, therefore:**

```
one shared frame image  +  per-page font rendering 15 lines of word-code text
```

This is almost certainly what KFGQPC does too, and it is why they can offer zoom
while shipping fidelity: **vector glyphs scale for free**. Greentech and
Quran.com omit zoom by *product choice*, not technical constraint — their page is
laid out to fit the viewport exactly once, and nobody wrapped it in a zoomable
canvas. That is the seam we exploit.

### The pack: per-page fonts

Each of the 604 pages gets its **own font file** whose glyphs are the exact
ligature forms appearing on that page, addressed by private-use codepoints. The
printed line breaks are given by the data, not computed by us. Distributed via
QUL as the QPC/QCF page-font set; **the spike must confirm we take the 1440H
Madani edition specifically**, since that is what Greentech ships and what the
owner's reference is.

- **Zoom is free and infinite** — vector glyphs, crisp at 8x. The headline
  feature costs nothing.
- **The text layer is real text**, so verse tap, selection, audio highlight and
  bookmarks fall out of normal Flutter hit-testing. **No bounding-box index to
  ship, version, or keep in sync** — that whole subsystem disappears.
- **Colour is ours to control** at word granularity: pink waqf marks, blue
  rosettes, black body.
- **~25–45 MB** for the pack (604 × ~30–70 KB), versus 90–150 MB for images.
- **Not "unicode text"** in the sense the owner means: page-local glyph codes,
  not `text_arabic_uthmani`. We are not re-rendering our flowing text prettier.
- **Cost:** the frame, title band, running heads and page number are ours to
  draw — but as *one* image asset plus a few text widgets, not per page.
- **Risk:** 604 font families is unusual load on the engine. Lazy per-page load
  with LRU eviction is mandatory, never a preload. Verify in the spike.

### Rejected: a 604-page image pack

Kept only as the fallback if licensing (§3) blocks the fonts. Pixel-exact
including the frame, but: 90–150 MB; raster caps zoom around 3–4x; ~20 MB
resident per decoded page; and every interactive feature needs a shipped
per-ayah bounding-box index that fails *silently* when it drifts from the
artwork (taps land on the wrong verse, nothing throws). Strictly worse on every
axis the owner cares about, including the one it was supposed to win.

---

## 3. Phase 0 — gates before any app code (do not skip)

1. **Licensing.** The QPC page fonts carry a stated licence via QUL — check its
   terms for redistribution inside a closed-source app. The **frame artwork** is
   the separate question: if KFGQPC's own border cannot be redistributed, we
   commission or design our own in the house style ([docs/brand.md](brand.md)),
   which is a contained design task rather than a blocker. This lands on the
   licensing gate already blocking fonts and translations pre-release.
2. **Fidelity + engine spike** (~1–2 days, throwaway), pages 1, 77, 255, 604:
   - render 15 lines from the page font, justified to the printed width;
     screenshot and diff against the print — **line breaks must match exactly**;
   - colour the waqf marks pink and the rosettes blue via per-word spans, and
     confirm it matches the reference;
   - wrap the page in `InteractiveViewer` and zoom to 6x — confirm crispness
     and 60fps pan on the OnePlus 15R;
   - **load and evict 30 page fonts in sequence**, watching resident memory.
     This is the one genuinely unproven assumption in the plan;
   - check in the reference app **whether the decorative frame recolours** along
     with the text — that is what tells us the frame must be vector (§2).

Exit criteria: written licence position + a zoomed spike screenshot the owner
signs off against the print.

---

## 4. Phase 1 — the pack pipeline (`../alquran-data`)

New `build_mushaf_packs.py`, sibling to `build_editions.py`. One pack, not 604
downloads:

```
mushaf-madani-1440.pack.gz
  fonts/p001.ttf … p604.ttf
  layout.sqlite    -- words(page, line, position, glyph_code, surah_id,
                   --       ayah_number, kind)  +  lines(page, line, kind)
  manifest.json    -- slug, version, pageCount, per-file sha256
```

- `layout.sqlite` is the whole interaction layer: which glyph code sits at each
  position on each line, which ayah it belongs to, and `kind` ∈
  `word | waqf | ayah_marker` so the renderer knows what to colour. `lines.kind`
  distinguishes text lines from surah-title bands and basmala lines.
- Cross-check the page→ayah mapping against our existing `ayahs.page_number`
  (604 pages, 6236 ayahs). **Any mismatch is a build failure, not a warning.**
- Catalogue: extend `catalogue.json` with `"type": "mushaf"`. `CatalogueEntry`
  already carries `type` and both digests, so the existing schema absorbs this
  **without a breaking change** — `ayahCount` is the only awkward field, set to
  6236.
- **Identity by slug, never DB id.** Same rule as editions.

## 5. Phase 2 — install/remove in the app

Reuse `EditionRepositoryImpl` mechanics, not the class. Its two invariants carry
over verbatim and are why this is low-risk:

1. nothing installs without matching **both** digests (transfer + expanded);
2. downloads live outside `quran.db`, which is overwritten on version bumps.

New `MushafPackRepository` in `features/reader/data/` — the pack is a reader
concern, not a translations concern, so no cross-feature import. Installs to the
support dir under `mushaf/<slug>/`. Must support resumable download, progress,
size shown before download, remove-and-reclaim-all-bytes, and re-verify on
launch: a half-deleted pack presents as *not installed*, never as a partially
blank Mushaf.

## 6. Phase 3 — the renderer

```
MushafPageView
  └ PageView (horizontal, reverse: true — RTL, turns right to left)
      └ MushafPage(pageNumber)
          └ InteractiveViewer(minScale: 1, maxScale: 6)
              └ AspectRatio(printed page ratio)
                  └ Stack
                      ├ PageFrame        (one shared SVG — vector so it stays
                      │                   crisp at 6x zoom AND is recolourable)
                      ├ RunningHeads     (juz + surah, from layout.sqlite)
                      ├ Column of 15 MushafLine
                      │    └ RichText of per-word TextSpans in the page font,
                      │      coloured by `kind`, stretched to the line width
                      └ PageNumber       (Arabic-Indic — the one place we use them)
```

Decisions baked in:

- **Justification is per-line fitting, not `TextAlign.justify`.** Each line is
  laid out then scaled to fill the printed measure (a `FittedBox`-style fit), so
  every line reaches both margins exactly as printed. Flutter's `justify` on
  Arabic will not reliably reproduce it.
- **Font lifecycle.** Load the page font on page build, keep a ~5-page LRU, evict
  beyond it. Never preload 604. Precache ±1 page so a turn is never blank.
- **Zoom persists across page turns, pan resets to top.** Matches KFGQPC and is
  what a reader with weak eyesight actually wants — they set their scale once.
  Double-tap toggles fit ↔ 2.5x. **This is our differentiator; treat it as a
  first-class feature, not a wrapper.**
- **Page turn is disabled past ~1.05x zoom**, otherwise pan fights the
  `PageView`. Pan to the edge, then turn.
- **Page number is the unit of position** for last-read and resume.

## 7. Phase 4 — verse interaction

Each word span carries its ayah id, so a tap resolves through normal text
hit-testing — no coordinate maths, no bbox data. That ayah id is the same one
the rest of the app already uses, so everything reconnects with no new concepts:

- **Tap a verse** → highlight the whole verse's runs across lines, and open the
  verse sheet: **translations** (the Detailed-view content, since the page has
  none) plus play, bookmark, share. This is the Greentech/Quran.com interaction
  the owner is pointing at, and we already have every piece of that sheet.
- **Selection** → long-press selects the verse; copy/share reuse `ayah_share`.
- **Audio** → highlight the playing ayah's runs; auto-turn the page when
  recitation crosses a boundary. Continuous play already exists.
- **Bookmarks** → unchanged ayah ids; render as a margin mark.
- **Continue reading** → stores the page; the banner deep-links back into it.

## 8. Phase 5 — integration, and the conflicts to settle

- **Light of Day vs the printed page.** Real conflict: the page has its own cream
  paper and green/pink frame, and tinting it by prayer phase will fight the
  artwork and can look soiled. **Recommendation:** apply the light temperature to
  the *page surround* only, leaving the page at its printed colour — the Mushaf
  reads as a physical page resting on our adaptive surface. Dark mode inverts the
  surround, never the page. (Fonts do give us the option of a true dark page
  later; deliberately out of scope for v1.)
- **Page colour customisation** — the reference app makes every colour
  configurable, and this build gets it nearly free: body text, waqf marks and
  ayah markers are already separate spans keyed by `words.kind`, and an SVG
  frame is recolourable. **Recommendation: ship a small curated set of page
  themes, not a colour picker per element.** A picker lets a reader produce an
  unreadable or undignified Mushaf, and the quality bar here is an *experience*,
  not a settings screen. Curated themes also let Light of Day drive the page
  properly rather than tinting over it — which is the cleaner answer to the
  conflict above, and worth revisiting once this lands.
- **Tajweed becomes reachable** (roadmap #7) once colour is per-span and the
  pack is word-addressed. Out of scope here; note it so the schema does not
  foreclose it.
- **Page navigation vs `advancedNavigation = false`.** v1 ships Surah-only, but a
  page-based Mushaf without a page jumper is hostile. **Recommendation:** surface
  a page/juz jumper *inside this viewport only*, independent of the global flag.
- **Feature flag:** `FeatureFlags.mushafPageMode`, dark until the pack ships. The
  viewport enum and settings entry stay hidden while false, and the app must not
  fetch the pack catalogue entry at all.

---

## 9. Acceptance gates

Ship blockers, not nice-to-haves:

1. **604/604 pages render** with **zero `.notdef`** glyphs — the same bar we held
   the Noorehuda IndoPak font to.
2. **Line-for-line fidelity** on a sampled 30 pages incl. 1, 2, 77, 255, 604:
   every printed line break reproduced, both margins reached, coloured waqf marks
   and rosettes correct. Verified against the print by the owner.
3. **Zoom to 6x stays crisp** and pans at 60fps on the OnePlus 15R. *The feature
   the references lack — hold this one hardest.*
4. **Memory ceiling** — paging through a full juz does not grow resident memory,
   proving font eviction works. The likeliest failure mode of this approach.
5. **Page open ≤ 100ms**, matching the bar the Reading-view virtualization set.
6. **Fully offline after install**; remove reclaims 100% of the bytes.
7. **Every existing reader feature reachable from the page**: tap→translations,
   audio, bookmarks, share, selection, continue reading.

## 10. What this is *not*

- Not on the website. Not now, not implicitly later.
- Not a replacement for Reading or Detailed view — a third option, off by
  default, opted into by downloading the pack.
- Not bundled in the APK. Even at 25–45 MB it cannot ride in the app download;
  that is the entire reason roadmap #2 is a *downloadable pack*.
- Not word-by-word. The pack is word-addressed, which makes per-word tap
  reachable later, but it stays out of scope here.
- Not full-text searchable. The page carries glyph codes, not searchable Arabic;
  search stays the job of `quran.db` and the flowing views.
