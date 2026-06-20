# Benchmark — Greentech "Al Quran (Tafsir & by Word)"

The PRD north-star app (`com.greentech.quran`, 13M+ users). Notes from reviewing
its store listing, developer page, and user reviews (2026-06). Goal: learn the
quality bar and avoid known pitfalls **without** abandoning our lean positioning.

## Their identity vs ours
Greentech is a deep **study tool** (word-by-word, 90+ translations, tafsir, audio,
grammar/E3rab, planner, sync). That breadth is also its weight. **We are the
opposite bet:** an ultra-light, fast, beautiful, fully-offline reader for
Urdu/Hindi subcontinent readers (PRD persona). Don't chase feature parity — win
on speed, clarity, and a frictionless core reading experience.

## What users love (validates our choices)
- **Fully offline, ad-free, no hidden charges** — same as our PRD.
- **Font sizing** — repeatedly praised. We have pinch-zoom + A−/A+, persisted. ✅
- **Night mode / themes** — we shipped light/dark. ✅
- **Multiple translations + transliteration together** — we have Urdu + English,
  data-driven. ◑
- **Copy & share verses** — we have selection/copy; no explicit Share yet. ◑
- Word-by-word, audio (30+ qaris, repeat for hifz), tafsir, search, planner —
  loved, but backlog/out for us.

## Recurring complaints → our quality checklist
- **Translation bleeds into the next ayah** (e.g., Surah Nuh 23→24). We key
  translations by `ayah_id`, so structurally safe — spot-check the data anyway.
- **Removing a bookmark leaves the mark.** If we add bookmarks, test add/remove.
- **Search crashes on nested root search; root matches not highlighted.** If we
  add FTS search, fuzz nested queries and highlight matches.

## Recommended moves (scope-tagged)
1. now · low-effort: **Share/Copy an ayah** (explicit affordance: Arabic +
   translation + reference). Builds on `SelectionArea`.
2. near-term: **Bookmarks** (extends last-read infra; mind the removal bug).
3. near-term: **Autoscroll** (memorization aid; small, loved).
4. backlog (owner sign-off): audio recitation, word-by-word, tafsir, FTS search,
   exact-Mushaf page mode, reading planner/streaks. Sync needs a backend →
   conflicts with our zero-backend ethos; long-term only.

Sources: gtaf.org/apps/quran · play.google.com/store/apps/details?id=com.greentech.quran
· apps.apple.com/us/app/al-quran-tafsir-by-word/id1437038111
