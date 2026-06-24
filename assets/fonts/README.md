# Fonts

Bundled faces (declared in `pubspec.yaml`):

- **`UthmanicHafs1-Ver18.ttf`** — family `UthmanicHafs`, the primary Arabic face
  (PRD 4.1). KFGQPC HAFS Uthmanic Script — **UthmanicHafs1 Ver18, Regular (weight
  400)**. This is the regular-weight KFGQPC face the **quran.com web reader** ships
  (`verses.quran.foundation/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.woff2`,
  converted woff2→ttf for Flutter — glyphs unchanged). It pairs with the
  `quran.ar.uthmani.v2.db` text we ship: madd, tanween and sukun render from the
  **bare QPC encoding** (no tatweel-grafting / mark-stripping in the pipeline), and
  the ayah-number Arabic-Indic digits compose — via the font's GSUB — into the
  ornate end-of-ayah rosette **with the number inside**. We enable `calt`/`rlig`/
  `liga` (`AppTheme.arabicFontFeatures`) for lam-alef etc.
  **Why this and not the others:** the older thetruetruth `UthmanicHafsV18.ttf`
  forced per-glyph tatweel-grafting; the quran-ios `UthmanicHafs1B Ver13` works but
  is the **Bold** cut (weight 700, macStyle bold) — it rendered heavy and, declared
  without a weight, made iOS fall back to a system Naskh face. This Regular/400 cut
  is light, elegant, and matches cleanly with no weight workaround.
  Source: quran.com / Quran Foundation CDN (the `.ttf` itself is KFGQPC).
  **Font licence UNVERIFIED (KFGQPC terms) — confirm before shipping.**

- **`NotoNastaliqUrdu-Regular.ttf`** — family `NotoNastaliqUrdu`, the Urdu
  translation face. Noto Nastaliq Urdu by Google, SIL Open Font License 1.1.

- **`PlayfairDisplay-SemiBold.ttf`** — family `PlayfairDisplay`, the display
  serif used for the surah English name in the chapter header. Playfair Display
  by Claus Eggers Sørensen, SIL Open Font License 1.1 (licence-clean). This is
  the variable-weight file from Google Fonts; we render it around weight 600.
  Swap the face by changing `AppTheme.displayFontFamily`.

- **`Noorehuda.ttf`** — family `Noorehuda`, the **IndoPak (South-Asian Naskh)**
  Quran face, behind `FeatureFlags.indopakScript`. By **abu saad /
  noorehidayat.org** (v1.002). **Licence: CC BY-NC** — free for non-commercial
  use **with attribution**, which this free / da'wah app satisfies; credit the
  Noor-e-Hidayat project in an about/credits screen, and re-clear before any
  paid/commercial release. Renders the `text_arabic_indopak` column — the
  **authentic Quran.com IndoPak** text (`text_indopak`), normalised for this font
  in the data pipeline (PUA marks mapped/stripped) — in IndoPak Naskh style; it is
  "ligature-free" so it shapes correctly in Flutter (no `liga` dependency).

`Kitab` is the planned alternate naskh face.
