#!/usr/bin/env python3
"""Neutralise KFGQPC's Tajweed-form alef-maqsura substitution.

Root cause of the "elongated madd hugs the letter" bug (e.g. ٱلۡيَتَٰمَىٰٓ,
ٱلۡأَعۡمَىٰ): in `UthmanicHafs1-Ver18.ttf` the `calt` feature, in the context of a
word-final alef-maqsura preceded by **meem**, chains into a Single-Substitution
lookup that swaps the normal final alef-maqsura (`afii57450.zz04`) for a
**Tajweed-form glyph `TJ065`**. `TJ065`'s superscript-alef / madd anchor sits very
low (mark y≈75 vs ≈480 on the normal form), so the madd collapses onto the letter.

The fix is surgical: rewrite that single substitution to an **identity** map, so the
chain still fires but produces no glyph change — the alef-maqsura keeps its normal
high-madd form. EVERYTHING else is untouched:
  • `calt` stays on, so the Allah / Bismillah ligatures are preserved.
  • Other `ـىٰ` words (after lam, ra, waw, …) never hit TJ065 — unchanged.
  • The taa's dagger-alef and all other marks in the word — unchanged.

This is why per-word `font-feature -calt` is the WRONG fix (it disrupts every mark
in the word and shifts already-correct words); the defect is one font lookup, so we
fix it in the font.

Idempotent: re-running on an already-patched font is a no-op (no TJ065 targets left).

Upstream original: the KFGQPC "Uthmanic Hafs 1 Ver18" face shipped with quran.com's
quran-ios resources (github.com/quran). Re-derive by downloading that .ttf and
running this tool on it.

NOTE: KFGQPC font licensing is UNVERIFIED; modifying the font must be cleared with
the King Fahd Complex terms before any public release (see CLAUDE.md / ATTRIBUTION).

Usage:
  python3 tool/patch_arabic_font.py [path/to/font.ttf]   # patches in place
"""
import sys

from fontTools.ttLib import TTFont

DEFAULT = "assets/fonts/UthmanicHafs1-Ver18.ttf"
TAJWEED_GLYPH = "TJ065"  # Tajweed-form alef-maqsura with the low madd anchor


def patch(path: str) -> int:
    font = TTFont(path)
    gsub = font["GSUB"].table
    neutralised = 0
    for lookup in gsub.LookupList.Lookup:
        if lookup.LookupType != 1:  # Single Substitution
            continue
        for sub in lookup.SubTable:
            mapping = getattr(sub, "mapping", None)
            if not mapping:
                continue
            for key, value in list(mapping.items()):
                if value == TAJWEED_GLYPH:
                    mapping[key] = key  # identity → no Tajweed swap
                    neutralised += 1
    if neutralised:
        font.save(path)
    return neutralised


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    n = patch(target)
    if n:
        print(f"Patched {target}: neutralised {n} → {TAJWEED_GLYPH} substitution(s).")
    else:
        print(f"{target}: already patched (no {TAJWEED_GLYPH} substitutions found).")
