#!/usr/bin/env python3
"""Consolidated DELTA report across all 114 surahs: render ONLY the verses that
differ from quran.com's QPC Hafs at the reading level (ours vs quran.com, app
font, with plain-language notes). Clean surahs collapse to one line — no full
verse dumps. Writes tool/uthmani_deltas.html."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_uthmani as vu
import visual_diff as vd

TOOL = Path(__file__).resolve().parent


def verse_block(s, a, ours_t, qc_t, rd):
    diffset = {o for o, _ in rd} | {t for _, t in rd}

    def hi(text):
        return " ".join(f'<span class="hl">{w}</span>'
                        if any(w and w in d for d in diffset) else w
                        for w in text.split())
    out = ['<div class="verse">',
           f'<div class="lbl">{s}:{a} — ours</div><div class="ar ours">{hi(ours_t)}</div>',
           f'<div class="lbl">{s}:{a} — quran.com (QPC Hafs)</div>'
           f'<div class="ar theirs">{hi(qc_t)}</div>']
    for o, t in rd:
        out.append('<div class="note">'
                   f'<div class="ar"><span class="ours">{o}</span> '
                   f'<span class="arrow">vs</span> <span class="theirs">{t}</span></div>')
        for oc, tc, on, tn in vd.char_notes(o, t):
            out.append(f'<div style="flex:1"><span class="ar small ours chip">{oc}</span>'
                       f'<span class="arrow"> → </span>'
                       f'<span class="ar small theirs chip">{tc}</span><br>'
                       f'<span class="ours">{on}</span> <span class="arrow">↔</span> '
                       f'<span class="theirs">{tn}</span></div>')
        out.append('</div>')
    out.append('</div>')
    return "\n".join(out)


def main():
    deltas, clean, errors = [], [], []
    total_ayahs = 0
    for s in range(1, 115):
        ours = vu.load_db(vu.APP_DB, s)
        total_ayahs += len(ours)
        try:
            qc = vu.load_qurancom(s, False)
        except Exception as e:  # noqa: BLE001
            errors.append(f"{s}: {e}")
            continue
        had = False
        for a in sorted(ours):
            pairs = vd.align(vd.words(ours[a]), vd.words(qc.get(a, "")))
            rd = [(o, t) for o, t in pairs if vu.clusters(o) != vu.clusters(t)]
            if rd:
                deltas.append(verse_block(s, a, ours[a], qc.get(a, ""), rd))
                had = True
        if not had:
            clean.append(s)
        print(f"surah {s:3}: {'DELTA' if had else 'clean'}")

    parts = [vd.HTML_HEAD.format(n="1–114 · deltas only")]
    if not deltas:
        parts.append(
            f'<div class="intro"><p class="ok" style="font-size:20px">✓ All 114 surahs '
            f'/ {total_ayahs} ayahs match quran.com’s displayed QPC Hafs text at the '
            f'reading level — 0 differences.</p><p>(Kashida madd-carriers, spacing and '
            f'mark-order aside, which render identically.)</p></div>')
    else:
        sm = {}
        for b in deltas:
            key = b.split(" — ")[0].split(">")[-1]
            sm[key] = sm.get(key, 0) + 1
        parts.append(
            f'<div class="intro"><p><b>{len(deltas)} ayah(s)</b> across the Qur’an differ '
            f'from quran.com at the reading level (rendered below); the other '
            f'{114 - len(set(k.split(":")[0] for k in sm))} surahs are clean.</p></div>')
        parts.extend(deltas)
    if errors:
        parts.append('<div class="intro"><p>fetch errors: ' + "; ".join(errors) + "</p></div>")
    parts.append("</body></html>")
    out = TOOL / "uthmani_deltas.html"
    out.write_text("\n".join(parts), encoding="utf-8")
    print(f"\nclean surahs: {len(clean)}/114 | delta ayahs: {len(deltas)} | errors: {len(errors)}")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
