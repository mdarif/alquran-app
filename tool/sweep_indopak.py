#!/usr/bin/env python3
"""Sweep every surah: compare our IndoPak text (text_arabic_indopak, normalised
for the Noorehuda font) to quran.com's `text_indopak` (what the site renders).

Reports, per surah and overall: kashida_extra, raw-differing ayahs, and a TALLY
of the character-level (ours -> quran.com) difference TYPES so we can see exactly
what the Noorehuda normalisation changed. Cached per surah.
"""

import json
import sqlite3
import sys
import unicodedata
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_uthmani as vu  # reuse cache dir + strip helper

TAT = "ـ"
API = ("https://api.quran.com/api/v4/verses/by_chapter/{n}"
       "?fields=text_indopak&per_page=50&page={p}")


def cp(ch):
    try:
        return f"U+{ord(ch):04X} " + unicodedata.name(ch).replace("ARABIC ", "")
    except ValueError:
        return f"U+{ord(ch):04X} ?"


def strip_trailing(t):
    """Drop trailing ayah-number digits, spaces, and bidi/format marks."""
    while t and (t[-1].isspace() or unicodedata.category(t[-1]) == "Cf"
                 or 0x0660 <= ord(t[-1]) <= 0x0669):
        t = t[:-1]
    return t


def load_qc(surah, refresh=False):
    vu.CACHE_DIR.mkdir(exist_ok=True)
    cache = vu.CACHE_DIR / f"quran_com_indopak_{surah}.json"
    if cache.exists() and not refresh:
        verses = json.loads(cache.read_text(encoding="utf-8"))
    else:
        verses, page = {}, 1
        while True:
            req = urllib.request.Request(API.format(n=surah, p=page),
                headers={"User-Agent": "alquran-verify/1.0", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode("utf-8"))
            for v in d["verses"]:
                verses[v["verse_key"].split(":")[1]] = v["text_indopak"]
            pg = d.get("pagination") or {}
            if page >= (pg.get("total_pages") or 1):
                break
            page += 1
        cache.write_text(json.dumps(verses, ensure_ascii=False), encoding="utf-8")
    return {int(k): strip_trailing(v) for k, v in verses.items()}


def main():
    import difflib

    con = sqlite3.connect(f"file:{vu.APP_DB}?mode=ro", uri=True)
    tally, raw_diff_ayahs, tot_extra = {}, 0, 0
    surahs = [int(x) for x in sys.argv[1:]] or range(1, 115)
    for s in surahs:
        ours = {a: t for a, t in con.execute(
            "SELECT ayah_number,text_arabic_indopak FROM ayahs WHERE surah_id=? "
            "ORDER BY ayah_number", (s,)).fetchall()}
        try:
            qc = load_qc(s)
        except Exception as e:  # noqa: BLE001
            print(f"surah {s}: fetch error {e}")
            continue
        for a in sorted(ours):
            o = strip_trailing(unicodedata.normalize("NFC", ours[a] or ""))
            q = unicodedata.normalize("NFC", qc.get(a, ""))
            tot_extra += max(0, o.count(TAT) - q.count(TAT))
            if o == q:
                continue
            raw_diff_ayahs += 1
            for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
                    None, o, q, autojunk=False).get_opcodes():
                if tag == "equal":
                    continue
                k = ((" ".join(cp(c) for c in o[i1:i2]) or "∅") + "  →  "
                     + (" ".join(cp(c) for c in q[j1:j2]) or "∅"))
                e = tally.setdefault(k, [0, f"{s}:{a}"])
                e[0] += 1

    print(f"surahs swept: {len(list(surahs))}")
    print(f"raw-differing ayahs: {raw_diff_ayahs}")
    print(f"kashida extra (ours over quran.com): {tot_extra}")
    print(f"\ncharacter-level difference TYPES ({len(tally)}):")
    for k, (c, ex) in sorted(tally.items(), key=lambda kv: -kv[1][0]):
        print(f"  {c:5}x  {k}   (e.g. {ex})")


if __name__ == "__main__":
    main()
