# Fonts

Bundled faces (declared in `pubspec.yaml`):

- **`UthmanicHafsV18.ttf`** — family `UthmanicHafs`, the primary Arabic face
  (PRD 4.1). KFGQPC HAFS Uthmanic Script **V2 (Ver 0.18)** — the
  HarfBuzz-compatible release from the King Fahd Quran Printing Complex. Its
  lam-alef ligature forms natively via `rlig`/default OpenType features (which
  Flutter applies), even with vowels between the letters. This replaced the old
  v0.09, whose ligature sat under `liga` — a feature Flutter does not apply for
  Arabic, so the lam and alef rendered detached.
  Source: https://qul.tarteel.ai (mirror: github.com/thetruetruth/quran-data-kfgqpc,
  `hafs/font/hafs.18.ttf`). **Licence UNVERIFIED — confirm before shipping.**

- **`NotoNastaliqUrdu-Regular.ttf`** — family `NotoNastaliqUrdu`, the Urdu
  translation face. Noto Nastaliq Urdu by Google, SIL Open Font License 1.1.

`Kitab` is the planned alternate naskh face.
