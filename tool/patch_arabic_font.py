#!/usr/bin/env python3
"""Lift the elongated-madd anchor on KFGQPC's alef-maqsura glyphs.

Root cause of the "madd hugs the letter" bug (ٱلۡيَتَٰمَىٰٓ, حَتَّىٰ, ٱلۡأَعۡمَىٰ, …):
KFGQPC ships the word-final alef-maqsura in a whole **family** of contextual /
Tajweed-form glyphs (the standard `afii57449`, plus `TJ043 TJ062 TJ065 TJ067 TJ082
TJ083 TJ136`, and `afii57450.zz04`). Their GPOS **mark-to-base anchors** for the
superscript-alef (`uni0670`) and the composed dagger-alef+maddah (`uni0670_uni0653`)
are INCONSISTENT: the standard `afii57449` seats the madd high at Y=550, but several
Tajweed forms seat it as low as Y=75–350, so on those words the madd collapses onto
the letter. (Shaping all 664 `ـىٰ` words in the DB: 138 use the good `afii57449`/550;
~166 land on a low-anchored form.)

The fix is at the FONT and is uniform: for every alef-maqsura form (identified as any
base glyph that carries the *composed madd* anchor — only word-final alef-maqsura
does), raise its dagger + madd base-anchors to the reference (`afii57449`'s 550). No
GSUB changes, so every glyph keeps its shape and all ligatures/contextual forms are
untouched; just the mark sits where the standard form puts it.

This supersedes the earlier per-word `-calt` hack (disrupted other marks) and the
single-glyph GSUB neutralisation (TJ065 only — missed the rest of the family).

Idempotent: anchors already ≥ reference are left alone.

Upstream original: KFGQPC "Uthmanic Hafs 1 Ver18" from quran.com's quran-ios
resources (github.com/quran). NOTE: KFGQPC licensing is UNVERIFIED — modifying the
font must be cleared with the King Fahd Complex terms before release (see CLAUDE.md).

Usage:
  python3 tool/patch_arabic_font.py [path/to/font.ttf]   # patches in place
"""
import sys

from fontTools.ttLib import TTFont

DEFAULT = "assets/fonts/UthmanicHafs1-Ver18.ttf"
DAGGER = "uni0670"  # superscript (dagger) alef
MADD = "uni0670_uni0653"  # composed dagger-alef + maddah (word-final alef-maqsura only)
REFERENCE_GLYPH = "afii57449"  # the standard alef-maqsura; its anchor is the target


def _mark_classes(subtable):
    """Return {markGlyph: classIndex} for the dagger/madd marks in this subtable."""
    out = {}
    for i, g in enumerate(subtable.MarkCoverage.glyphs):
        if g in (DAGGER, MADD):
            out[g] = subtable.MarkArray.MarkRecord[i].Class
    return out


def patch(path: str) -> int:
    font = TTFont(path)
    gpos = font["GPOS"].table
    subtables = [
        st
        for lk in gpos.LookupList.Lookup
        if lk.LookupType == 4  # MarkToBase
        for st in lk.SubTable
    ]

    # 1) Reference Y = the standard alef-maqsura's madd anchor (the high, correct one).
    reference = None
    for st in subtables:
        cls = _mark_classes(st)
        if MADD not in cls:
            continue
        for i, g in enumerate(st.BaseCoverage.glyphs):
            if g == REFERENCE_GLYPH:
                anchor = st.BaseArray.BaseRecord[i].BaseAnchor[cls[MADD]]
                if anchor is not None:
                    reference = anchor.YCoordinate
    if reference is None:
        print(f"{path}: reference glyph {REFERENCE_GLYPH} not found; nothing done.")
        return 0

    # 2) Raise every alef-maqsura form (= any base carrying the composed-madd anchor)
    #    so its dagger + madd anchors sit at the reference.
    raised = 0
    for st in subtables:
        cls = _mark_classes(st)
        if MADD not in cls:
            continue
        for i, g in enumerate(st.BaseCoverage.glyphs):
            rec = st.BaseArray.BaseRecord[i]
            if rec.BaseAnchor[cls[MADD]] is None:
                continue  # not an alef-maqsura form
            for mark in (MADD, DAGGER):
                if mark not in cls:
                    continue
                anchor = rec.BaseAnchor[cls[mark]]
                if anchor is not None and anchor.YCoordinate < reference:
                    anchor.YCoordinate = reference
                    raised += 1
    if raised:
        font.save(path)
    return raised


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    n = patch(target)
    if n:
        print(f"Patched {target}: raised {n} alef-maqsura madd anchor(s) to the "
              f"{REFERENCE_GLYPH} reference.")
    else:
        print(f"{target}: already patched (all madd anchors at/above reference).")
