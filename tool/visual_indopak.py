#!/usr/bin/env python3
"""Render our IndoPak text (text_arabic_indopak) in the Noorehuda font next to
quran.com's text_indopak, highlighting letter-form differences — so we can SEE
the actual app rendering and judge it (no assumptions). quran.com's text is shown
with its IndoPak-font PUA glyph-codes + zero-width marks stripped (Noorehuda is a
Unicode font; those are exactly what our build normalises away).

    python3 tool/visual_indopak.py --surah 1
    open tool/indopak_diff_1.html
"""

import argparse
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_uthmani as vu  # APP_DB, CACHE_DIR

TOOL = Path(__file__).resolve().parent

PLAIN = {
    0x0643: "kaf ك",
    0x06AA: "swash kaf ڪ (IndoPak form)",
    0x064A: "yāʾ ي",
    0x06D2: "yeh barree ے (final yāʾ)",
    0x0649: "alif maqṣūra ى",
}


def name(ch: str) -> str:
    if ord(ch) in PLAIN:
        return PLAIN[ord(ch)]
    try:
        return unicodedata.name(ch).replace("ARABIC ", "")
    except ValueError:
        return f"U+{ord(ch):04X}"


def norm_qc(t: str) -> str:
    """quran.com text_indopak -> comparable Unicode: drop trailing ayah-number/
    bidi, drop PUA glyph-codes + zero-width marks, en-space -> space, collapse."""
    while t and (t[-1].isspace() or unicodedata.category(t[-1]) == "Cf"
                 or 0x0660 <= ord(t[-1]) <= 0x0669):
        t = t[:-1]
    out = []
    for ch in unicodedata.normalize("NFC", t):
        o = ord(ch)
        if 0xE000 <= o <= 0xF8FF:          # PUA: quran.com IndoPak-font glyph code
            continue
        if ch in "​‌‍‏":  # zero-width / bidi
            continue
        out.append(" " if ch == " " else ch)
    return " ".join("".join(out).split())


def norm_ours(t: str) -> str:
    return " ".join(unicodedata.normalize("NFC", t or "").split())


def char_notes(a: str, b: str):
    import difflib
    notes = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, a, b, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        ours = "".join(("◌" + c) if unicodedata.category(c) == "Mn" else c
                       for c in a[i1:i2]) or "—"
        theirs = "".join(("◌" + c) if unicodedata.category(c) == "Mn" else c
                         for c in b[j1:j2]) or "—"
        on = ", ".join(name(c) for c in a[i1:i2]) or "(nothing)"
        tn = ", ".join(name(c) for c in b[j1:j2]) or "(nothing)"
        notes.append((ours, theirs, on, tn))
    return notes


def align(o_words, q_words):
    import difflib
    sm = difflib.SequenceMatcher(None, o_words, q_words)
    pairs = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                pairs.append((o_words[i1 + k], q_words[j1 + k]))
        else:
            pairs.append((" ".join(o_words[i1:i2]), " ".join(q_words[j1:j2])))
    return pairs


HEAD = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>IndoPak (Noorehuda) — Surah {n}</title>
<style>
@font-face {{ font-family:'Noore'; src:url('../assets/fonts/Noorehuda.ttf'); }}
body {{ font-family:-apple-system,Segoe UI,Roboto,sans-serif; margin:0 auto; max-width:960px;
       padding:24px; color:#1b1a18; background:#fbf9f3; line-height:1.5; }}
h1 {{ font-size:22px; }}
.ar {{ font-family:'Noore',serif; direction:rtl; font-size:38px; line-height:2.2; }}
.small {{ font-size:30px; }}
.intro,.verse {{ background:#fff; border:1px solid #e7e1d3; border-radius:12px;
       padding:14px 18px; margin:14px 0; }}
.lbl {{ font-size:12px; letter-spacing:.04em; text-transform:uppercase; color:#9a8f78; }}
.hl {{ background:#fdeebf; border-radius:5px; padding:0 3px; }}
.note {{ display:flex; gap:14px; align-items:center; border-top:1px dashed #e7e1d3;
        padding:8px 0; font-size:14px; }}
.note .ar {{ font-size:32px; line-height:1.4; }}
.ours {{ color:#0b6b53; }} .theirs {{ color:#9a5b00; }} .arrow {{ color:#aaa; }}
.ok {{ color:#0b6b53; font-weight:600; }}
</style></head><body>
<h1>Surah {n}: IndoPak (our text in Noorehuda) vs quran.com text_indopak</h1>
<div class="intro"><p>Both rendered in the app's <b>Noorehuda</b> font.
<span class="ours">green = ours</span>, <span class="theirs">amber = quran.com</span>
(quran.com shown with its IndoPak-font PUA glyph-codes + zero-width marks stripped —
those don't exist in Noorehuda and are exactly what our build normalises). Words
that differ in actual letters are <span class="hl">highlighted</span>; everything
else is spacing/zero-width only.</p></div>
"""


def render(surah: int, all_verses: bool) -> str:
    con = sqlite3.connect(f"file:{vu.APP_DB}?mode=ro", uri=True)
    ours = {a: norm_ours(t) for a, t in con.execute(
        "SELECT ayah_number,text_arabic_indopak FROM ayahs WHERE surah_id=? "
        "ORDER BY ayah_number", (surah,)).fetchall()}
    cache = vu.CACHE_DIR / f"quran_com_indopak_{surah}.json"
    qc_raw = json.loads(cache.read_text(encoding="utf-8"))
    qc = {int(k): norm_qc(v) for k, v in qc_raw.items()}

    real = {}
    for a in sorted(ours):
        pairs = align(ours[a].split(), qc.get(a, "").split())
        rd = [(o, t) for o, t in pairs if o != t]
        if rd:
            real[a] = rd

    parts = [HEAD.format(n=surah)]
    if not real:
        parts.append(f'<div class="intro"><p class="ok" style="font-size:19px">✓ All '
                     f'{len(ours)} ayahs match quran.com letter-for-letter (Noorehuda).</p>'
                     f'</div>')
    else:
        parts.append(f'<div class="intro"><p><b>{len(real)} of {len(ours)} ayahs</b> have a '
                     f'letter-form difference vs quran.com (highlighted below).</p></div>')

    for a in (sorted(ours) if all_verses else sorted(real)):
        rd = real.get(a, [])
        diffset = {o for o, _ in rd} | {t for _, t in rd}

        def hi(text):
            return " ".join(f'<span class="hl">{w}</span>'
                            if any(w and w in d for d in diffset) else w
                            for w in text.split())
        parts.append('<div class="verse">')
        parts.append(f'<div class="lbl">{surah}:{a} — ours (Noorehuda)</div>'
                     f'<div class="ar ours">{hi(ours[a])}</div>')
        parts.append(f'<div class="lbl">{surah}:{a} — quran.com indopak</div>'
                     f'<div class="ar theirs">{hi(qc.get(a, ""))}</div>')
        for o, t in rd:
            parts.append('<div class="note">')
            parts.append(f'<div class="ar"><span class="ours">{o}</span> '
                         f'<span class="arrow">vs</span> <span class="theirs">{t}</span></div>')
            for oc, tc, on, tn in char_notes(o, t):
                parts.append(f'<div style="flex:1"><span class="ar small ours">{oc}</span>'
                             f'<span class="arrow"> → </span>'
                             f'<span class="ar small theirs">{tc}</span><br>'
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
    ap.add_argument("--all", action="store_true", help="render every ayah, not just diffs")
    args = ap.parse_args()
    out = TOOL / f"indopak_diff_{args.surah}.html"
    out.write_text(render(args.surah, args.all), encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
