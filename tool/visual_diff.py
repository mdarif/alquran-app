#!/usr/bin/env python3
"""Render a VISUAL, human-readable diff of our Uthmani text vs quran.com for one
surah — actual Arabic glyphs (app font), differing words highlighted, and a
plain-language note for every difference. Open the generated HTML in a browser.

    python3 tool/visual_diff.py --surah 1
    open tool/uthmani_diff_1.html
"""

import argparse
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_uthmani as vu  # reuse loaders + clustering

TOOL = Path(__file__).resolve().parent

# Plain-language names for the characters that differ between the two sources.
PLAIN = {
    0x064A: "yāʾ (dotted)",
    0x0649: "alif maqṣūra — a dotless yāʾ",
    0x0626: "yāʾ carrying hamza (precomposed ئ)",
    0x0624: "wāw carrying hamza (ؤ)",
    0x0621: "hamza (ء)",
    0x0654: "hamza mark (above)",
    0x0655: "hamza mark (below)",
    0x0653: "madda — long ā",
    0x0670: "dagger alif — long ā",
    0x06E1: "sukūn — QPC small-circle (letter has no vowel)",
    0x0652: "sukūn — standard (letter has no vowel)",
    0x06DF: "small circle — letter has no vowel",
    0x064B: "fatḥatān — the “-an” ending",
    0x064C: "ḍammatān — the “-un” ending",
    0x064D: "kasratān — the “-in” ending",
    0x0657: "QPC tanwīn glyph (small ḍamma form)",
    0x065E: "QPC tanwīn glyph (fatḥa, two dots)",
    0x0656: "QPC tanwīn glyph (subscript alif)",
    0x064E: "fatḥa — short a",
    0x064F: "ḍamma — short u",
    0x0650: "kasra — short i",
    0x0651: "shadda — doubled letter",
    0x06E2: "small meem — tajwīd (iqlāb)",
    0x06ED: "small meem — tajwīd",
    0x0640: "kashida — a stretch carrier (cosmetic)",
    0x0020: "a space",
}


def name(ch: str) -> str:
    base = PLAIN.get(ord(ch))
    if base:
        return base
    try:
        return unicodedata.name(ch).replace("ARABIC ", "").title()
    except ValueError:
        return "?"


def show_char(ch: str) -> str:
    """Render a combining mark on a dotted circle so it's visible standalone."""
    return ("◌" + ch) if unicodedata.category(ch) == "Mn" else ch


def word_rasm(w: str) -> str:
    return "".join(b for b, _ in vu.clusters(w))


def words(verse: str):
    """Words that carry letters (drop pure waqf-mark tokens), with their rasm."""
    out = []
    for w in verse.split():
        r = word_rasm(w)
        if r:
            out.append((w, r))
    return out


def align(ours, theirs):
    """Pair our words with quran.com's by their rasm skeleton."""
    import difflib

    sm = difflib.SequenceMatcher(None, [r for _, r in ours], [r for _, r in theirs])
    pairs = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                pairs.append((ours[i1 + k][0], theirs[j1 + k][0]))
        else:
            o = " ".join(w for w, _ in ours[i1:i2])
            t = " ".join(w for w, _ in theirs[j1:j2])
            pairs.append((o, t))
    return pairs


def char_notes(a: str, b: str):
    """Plain notes describing how word a (ours) differs from word b (quran.com)."""
    import difflib

    notes = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
        None, a, b, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        ours = "".join(show_char(c) for c in a[i1:i2]) or "—"
        theirs = "".join(show_char(c) for c in b[j1:j2]) or "—"
        on = ", ".join(name(c) for c in a[i1:i2]) or "(nothing)"
        tn = ", ".join(name(c) for c in b[j1:j2]) or "(nothing)"
        notes.append((ours, theirs, on, tn))
    return notes


HTML_HEAD = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Uthmani diff — Surah {n}</title>
<style>
@font-face {{ font-family:'Hafs'; src:url('../assets/fonts/UthmanicHafs1-Ver18.ttf'); }}
body {{ font-family:-apple-system,Segoe UI,Roboto,sans-serif; margin:0 auto; max-width:920px;
       padding:24px; color:#1b1a18; background:#fbf9f3; line-height:1.5; }}
h1 {{ font-size:22px; }} h2 {{ margin-top:34px; border-bottom:1px solid #d8d2c4; padding-bottom:6px; }}
.ar {{ font-family:'Hafs',serif; direction:rtl; font-size:34px; line-height:2.1; }}
.small {{ font-size:26px; }}
.intro {{ background:#fff; border:1px solid #e7e1d3; border-radius:12px; padding:16px 20px; }}
.verse {{ background:#fff; border:1px solid #e7e1d3; border-radius:12px; padding:14px 18px; margin:14px 0; }}
.lbl {{ font-size:12px; letter-spacing:.04em; text-transform:uppercase; color:#9a8f78; }}
.hl {{ background:#fdeebf; border-radius:5px; padding:0 3px; }}
.note {{ display:flex; gap:14px; align-items:center; border-top:1px dashed #e7e1d3;
        padding:8px 0; font-size:14px; }}
.note .ar {{ font-size:30px; line-height:1.4; }}
.chip {{ display:inline-block; min-width:46px; text-align:center; }}
.ours {{ color:#0b6b53; }} .theirs {{ color:#9a5b00; }}
.arrow {{ color:#aaa; }}
.ok {{ color:#0b6b53; font-weight:600; }}
</style></head><body>
<h1>Surah {n}: our text vs quran.com — what actually differs</h1>
<div class="intro">
<p><b>How to read this.</b> For each verse you see <span class="ours">our text</span> and
<span class="theirs">quran.com's text</span>, both in the app's KFGQPC font. Where a word
differs, it's <span class="hl">highlighted</span>, and below the verse each difference is
spelled out in plain words.</p>
<p><b>Two questions, in order:</b> (1) are the <b>letters / words</b> the same? (2) are the
<b>marks</b> (vowels, sukūn, tanwīn) the same — or just written with a different style?</p>
<p>Colours: <span class="ours">green = ours</span>, <span class="theirs">amber = quran.com</span>.
A “◌” just means the mark is shown on an empty circle so you can see it on its own.</p>
</div>
"""


def render(surah: int, all_verses: bool = False) -> str:
    ours = vu.load_db(vu.APP_DB, surah)
    qc = vu.load_qurancom(surah, refresh=False)
    real, cos_total = {}, 0
    for a in sorted(ours):
        pairs = align(words(ours[a]), words(qc.get(a, "")))
        # A "real" difference is one that survives normalisation (clusters);
        # everything else differs only in invisible encoding (spaces, kashida,
        # mark order) and renders the same.
        rd = [(o, t) for o, t in pairs if vu.clusters(o) != vu.clusters(t)]
        if rd:
            real[a] = rd
        cos_total += sum(1 for o, t in pairs
                         if o != t and vu.clusters(o) == vu.clusters(t))

    parts = [HTML_HEAD.format(n=surah)]
    if not real:
        parts.append(
            f'<div class="intro"><p class="ok" style="font-size:19px">✓ All {len(ours)} '
            f'ayahs match quran.com’s displayed text (QPC Hafs) at the reading level.</p>'
            f'<p>{cos_total} word(s) differ only in <i>invisible</i> encoding '
            f'(spacing · kashida stretch · mark order) — they render identically.</p></div>')
    else:
        parts.append(
            f'<div class="intro"><p><b>{len(real)} of {len(ours)} ayahs</b> have a '
            f'reading-level difference from quran.com (shown below). The other '
            f'{len(ours) - len(real)} are identical; {cos_total} word(s) across the surah '
            f'differ only in <i>invisible</i> encoding (spacing · kashida · mark order).</p></div>')

    for a in (sorted(ours) if all_verses else sorted(real)):
        rd = real.get(a, [])
        diffset = {o for o, _ in rd} | {t for _, t in rd}

        def hi(text):
            return " ".join(
                f'<span class="hl">{w}</span>' if any(w in d for d in diffset) else w
                for w in text.split())

        parts.append('<div class="verse">')
        parts.append(f'<div class="lbl">{surah}:{a} — ours</div>'
                     f'<div class="ar ours">{hi(ours[a])}</div>')
        parts.append(f'<div class="lbl">{surah}:{a} — quran.com (QPC Hafs)</div>'
                     f'<div class="ar theirs">{hi(qc.get(a, ""))}</div>')
        for o, t in rd:
            parts.append('<div class="note">')
            parts.append(f'<div class="ar"><span class="ours">{o}</span> '
                         f'<span class="arrow">vs</span> '
                         f'<span class="theirs">{t}</span></div>')
            for ours_c, theirs_c, on, tn in char_notes(o, t):
                parts.append(
                    f'<div style="flex:1"><span class="ar small ours chip">{ours_c}</span>'
                    f'<span class="arrow"> → </span>'
                    f'<span class="ar small theirs chip">{theirs_c}</span><br>'
                    f'<span class="ours">{on}</span> '
                    f'<span class="arrow">↔</span> '
                    f'<span class="theirs">{tn}</span></div>')
            parts.append('</div>')
        parts.append('</div>')
    parts.append("</body></html>")
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--surah", type=int, default=1)
    ap.add_argument("--all", action="store_true",
                    help="render EVERY ayah (ours vs quran.com), not just diffs")
    args = ap.parse_args()
    out = TOOL / f"uthmani_diff_{args.surah}.html"
    out.write_text(render(args.surah, all_verses=args.all), encoding="utf-8")
    print(f"wrote {out}")
    print(f"open it with:  open {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
