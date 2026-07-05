#!/usr/bin/env python3
"""Stop Noorehuda from floating waqf signs after a fatha/damma-class harakah.

Root cause of the "waqf sign hovers high-left of the word" bug (Al-Fatihah 2/5/6
الۡعٰلَمِيۡنَۙ / نَسۡتَعِيۡنُؕ / الۡمُسۡتَقِيۡمَۙ, and 1,853 ayah-endings like them):
Noorehuda's own GSUB pipeline first converts EVERY small-high waqf sign
(U+0615, U+06D6..U+06DB …) to a proper **spacing** glyph that sits inline after
the word (`ccmp` lookup 33 — this is how 5,188 of the corpus' 7,063 waqf signs
render, and how quran.com's IndoPak font presents them too). But a second rule
(`ccmp` lookup 34, one ChainContextSubst subtable) reverts the spacing form back
to a zero-width combining mark whenever the PREVIOUS glyph is an above-harakah
(fathah, dammah, shaddah, sukun, maddah, …), intending to stack the sign on the
harakah via mkmk. The mkmk anchor geometry is broken for that pair — the sign
lands ~155 units left and ~345 above the harakah, i.e. floating over the void
after the word.

The fix is at the FONT and is minimal: delete that one revert subtable, so the
harakah case falls through to the exact same spacing presentation as the other
73% of the corpus. No anchors touched, no other rules affected (the remaining
subtables of lookup 34 handle ornate-parenthesis contexts our text never hits).

Idempotent: a second run finds no matching subtable and does nothing.

Upstream original: Noorehuda (nooreHidayat family) — licensing UNVERIFIED, must
be cleared before release (see CLAUDE.md / ../alquran-data/HANDOFF.md).

Usage:
  python3 tool/patch_noorehuda_waqf.py [path/to/Noorehuda.ttf]   # patches in place
"""
import sys

from fontTools.ttLib import TTFont

DEFAULT = "assets/fonts/Noorehuda.ttf"

# The revert rule is identified structurally, not by index: a ChainContextSubst
# (format 3) whose backtrack is the above-harakah class and whose input is the
# spacing waqf forms. These two glyphs pin it down uniquely in Noorehuda.
BACKTRACK_SENTINEL = "fathah"        # any above-harakah in the backtrack class
INPUT_SENTINEL = ".notdef.280"       # the spacing form of U+06D9 (small lam-alef)


def _is_revert_rule(sub) -> bool:
    t = getattr(sub, "ExtSubTable", sub)
    if type(t).__name__ != "ChainContextSubst" or t.Format != 3:
        return False
    if t.LookAheadCoverage:  # the harakah rule has no lookahead
        return False
    backtrack = {g for c in t.BacktrackCoverage for g in c.glyphs}
    inputs = {g for c in t.InputCoverage for g in c.glyphs}
    return BACKTRACK_SENTINEL in backtrack and INPUT_SENTINEL in inputs


def patch(path: str) -> int:
    font = TTFont(path)
    gsub = font["GSUB"].table
    removed = 0
    for lookup in gsub.LookupList.Lookup:
        if lookup.LookupType not in (6, 7):
            continue
        keep = [st for st in lookup.SubTable if not _is_revert_rule(st)]
        removed += len(lookup.SubTable) - len(keep)
        if len(keep) != len(lookup.SubTable):
            lookup.SubTable = keep
            lookup.SubTableCount = len(keep)
    if removed:
        font.save(path)
    print(f"{path}: removed {removed} harakah-revert subtable(s).")
    return removed


if __name__ == "__main__":
    patch(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
