#!/usr/bin/env python3
"""Verify the bundled Uthmani matn against trusted references, verse by verse.

Two layers (see the plan):
  A. OFFLINE EXACT  — our DB vs the golden QPC source it's built from
     (../alquran-data/sources/quran.ar.uthmani.v2.db). After stripping the
     grafted kashidas (U+0640) from both, they must match byte-for-byte. Any
     diff is a real pipeline corruption.  [hard fail]
  B. quran.com      — our DB vs api.quran.com `text_uthmani`:
       • LETTERS (rasm)   -> the base-letter sequence must match    [hard fail]
       • MARKS per letter -> only NOVEL mark differences are shown; the
         systematic QPC-vs-quran.com encodings are catalogued in
         tool/known_uthmani_conventions.json (grow it with --learn).  [review]

We compare by letter CLUSTER (a base letter + its combining marks) so mark
differences read cleanly per letter instead of as a tangled character diff.

Scope with --surah (default 1 = Al-Fatihah). Read-only except --learn, which
appends accepted mark-convention pairs to the catalogue JSON.
"""

import argparse
import json
import sqlite3
import sys
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = Path(__file__).resolve().parent
APP_DB = ROOT / "assets/db/quran.db"
GOLDEN_DB = ROOT.parent / "alquran-data/sources/quran.ar.uthmani.v2.db"
CACHE_DIR = TOOL / ".cache"
CATALOGUE = TOOL / "known_uthmani_conventions.json"
# `text_qpc_hafs` is the QPC Hafs script the quran.com WEBSITE actually renders —
# the same KFGQPC text our DB is built from (NOT `text_uthmani`, which is a
# plainer Tanzil-style digitization the site doesn't display).
QC_API = ("https://api.quran.com/api/v4/verses/by_chapter/{n}"
          "?fields=text_qpc_hafs&per_page=50&page={p}")

TATWEEL = "ـ"  # kashida carrier (grafted into our build for font rendering)

# Letter-FORM folds for the rasm skeleton — orthographic variants of the SAME
# letter, so they never read as a wrong letter: alef-wasla -> bare alef, and the
# final-yaa dotting ى<->ي (our QPC dots it; quran.com's web text doesn't).
LETTER_FOLD = {0x0671: 0x0627, 0x0649: 0x064A}

# Precomposed hamza/madda letters expanded to base + combining mark, so the two
# sources encode them the same way (ours often decomposes ئ as ي+hamza; quran.com
# uses the precomposed letter, and vice-versa). Then the SEAT compares as a
# letter and the hamza/madda as a mark — no spurious letter mismatch.
HAMZA_DECOMPOSE = {
    0x0622: (0x0627, 0x0653),  # آ -> ا + maddah
    0x0623: (0x0627, 0x0654),  # أ -> ا + hamza above
    0x0625: (0x0627, 0x0655),  # إ -> ا + hamza below
    0x0624: (0x0648, 0x0654),  # ؤ -> و + hamza above
    0x0626: (0x064A, 0x0654),  # ئ -> ي + hamza above
}

# Waqf (pause) + section signs — editorial recitation guidance, NOT matn; they
# legitimately differ between QPC and quran.com, so we exclude them from the mark
# comparison entirely (neither flagged nor catalogued).
WAQF = set(range(0x06D6, 0x06DF))  # U+06D6..U+06DE


def cp(ch: str) -> str:
    try:
        name = unicodedata.name(ch)
    except ValueError:
        name = "?"
    return f"U+{ord(ch):04X} {name}"


def strip_tatweel(s: str) -> str:
    return s.replace(TATWEEL, "")


def clusters(s: str) -> list:
    """Split into (base_letter, sorted_marks) clusters. NFC, drop tatweel and
    spaces; expand precomposed hamza/madda; fold letter-forms; drop waqf signs;
    sort each letter's marks (order-insensitive)."""
    s = unicodedata.normalize("NFC", strip_tatweel(s))
    s = "".join(c for c in s if not c.isspace())  # drop ALL spaces (incl. NBSP)
    expanded = []
    for ch in s:
        if ord(ch) == 0x0621:  # standalone hamza ء -> combining hamza on prev letter
            expanded.append(chr(0x0654))
        else:
            expanded.extend(chr(c) for c in HAMZA_DECOMPOSE.get(ord(ch), (ord(ch),)))
    out = []
    for ch in expanded:
        o = ord(ch)
        if unicodedata.category(ch) == "Mn":  # combining mark
            if o in WAQF:
                continue  # editorial pause/section sign — not matn
            if out:
                out[-1][1].append(ch)
        else:
            out.append((chr(LETTER_FOLD.get(o, o)), []))
    return [(b, tuple(sorted(m))) for b, m in out]


def marks_label(m: tuple) -> str:
    return "[" + (" ".join(cp(c) for c in m) if m else "∅") + "]"


def diff_pairs(a: str, b: str) -> list:
    import difflib

    return [(a[i1:i2], b[j1:j2])
            for tag, i1, i2, j1, j2 in
            difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()
            if tag != "equal"]


def load_catalogue() -> set:
    if not CATALOGUE.exists():
        return set()
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    return {(tuple(int(x, 16) for x in o), tuple(int(x, 16) for x in t))
            for o, t in data["marks"]}


def save_catalogue(pairs: set) -> None:
    data = {
        "_comment": "Accepted QPC-vs-quran.com Uthmani MARK conventions per "
        "letter (our marks -> quran.com marks). Letters/rasm are not here. "
        "Grow with: python3 tool/verify_uthmani.py --surah N --learn.",
        "marks": sorted([[f"{c:04X}" for c in o], [f"{c:04X}" for c in t]]
                        for o, t in pairs),
    }
    CATALOGUE.write_text(json.dumps(data, ensure_ascii=False, indent=2),
                         encoding="utf-8")


def load_db(path: Path, surah: int) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT ayah_number, text_arabic_uthmani FROM ayahs "
        "WHERE surah_id=? ORDER BY ayah_number", (surah,)).fetchall()
    con.close()
    return {a: t for a, t in rows}


def load_golden(path: Path, surah: int) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT ayah, text FROM arabic_text WHERE sura=? ORDER BY ayah",
        (surah,)).fetchall()
    con.close()
    return {a: t for a, t in rows}


def _strip_end_number(t: str) -> str:
    """Drop the trailing ayah-number glyph (Arabic-Indic digits) quran.com appends."""
    while t and (t[-1].isspace() or 0x0660 <= ord(t[-1]) <= 0x0669):
        t = t[:-1]
    return t


def load_qurancom(surah: int, refresh: bool) -> dict:
    CACHE_DIR.mkdir(exist_ok=True)
    cache = CACHE_DIR / f"quran_com_qpchafs_{surah}.json"
    if cache.exists() and not refresh:
        verses = json.loads(cache.read_text(encoding="utf-8"))
    else:
        verses, page = {}, 1
        while True:
            req = urllib.request.Request(
                QC_API.format(n=surah, p=page),
                headers={"User-Agent": "alquran-verify/1.0", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode("utf-8"))
            for v in d["verses"]:
                verses[v["verse_key"].split(":")[1]] = v["text_qpc_hafs"]
            pg = d.get("pagination") or {}
            if page >= (pg.get("total_pages") or 1):
                break
            page += 1
        cache.write_text(json.dumps(verses, ensure_ascii=False), encoding="utf-8")
    return {int(k): _strip_end_number(t) for k, t in verses.items()}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--surah", type=int, default=1, help="chapter number (default 1)")
    ap.add_argument("--golden", type=Path, default=GOLDEN_DB)
    ap.add_argument("--no-network", action="store_true", help="skip quran.com")
    ap.add_argument("--refresh", action="store_true", help="re-fetch quran.com cache")
    ap.add_argument("--quiet", action="store_true", help="summary only (no per-ayah)")
    ap.add_argument("--learn", action="store_true",
                    help="add this surah's NOVEL mark pairs to the catalogue")
    args = ap.parse_args()
    n = args.surah

    ours = load_db(APP_DB, n)
    print(f"Surah {n}: {len(ours)} ayahs in our DB ({APP_DB.name})\n")
    golden = load_golden(args.golden, n) if args.golden.exists() else None
    if golden is None:
        print(f"  [layer A skipped] golden source not found at {args.golden}\n")
    qc = None
    if not args.no_network:
        try:
            qc = load_qurancom(n, args.refresh)
        except Exception as e:  # noqa: BLE001
            print(f"  [layer B skipped] quran.com fetch failed: {e}\n")

    catalogue = load_catalogue()
    hard_fails = 0
    rasm_types: dict = {}
    novel_types: dict = {}
    learned: set = set()

    def bump(tally, key_label, example):
        tally.setdefault(key_label, [0, example])
        tally[key_label][0] += 1

    for a in sorted(ours):
        t = ours[a]
        key = f"{n}:{a}"
        flags = []

        if golden is not None:
            if a not in golden:
                flags.append(("✗", "A", "missing in golden source", []))
                hard_fails += 1
            elif strip_tatweel(t) != strip_tatweel(golden[a]):
                d = [f"{marks_label(tuple(o))[1:-1]}  →  {marks_label(tuple(th))[1:-1]}"
                     for o, th in diff_pairs(strip_tatweel(t), strip_tatweel(golden[a]))]
                flags.append(("✗", "A", "EXACT MISMATCH vs golden", d))
                hard_fails += 1

        if qc is not None and a in qc:
            co, cq = clusters(t), clusters(qc[a])
            bo = "".join(b for b, _ in co)
            bq = "".join(b for b, _ in cq)
            if bo != bq:  # letter (rasm) mismatch
                detail = []
                for o, th in diff_pairs(bo, bq):
                    lbl = (" ".join(cp(c) for c in o) or "∅") + "  →  " + \
                          (" ".join(cp(c) for c in th) or "∅")
                    bump(rasm_types, lbl, key)
                    detail.append(lbl)
                flags.append(("✗", "B", "RASM (letters) MISMATCH vs quran.com", detail))
                hard_fails += 1
            else:  # letters match — compare marks per cluster
                novel = []
                for (b, mo), (_, mq) in zip(co, cq):
                    if mo == mq:
                        continue
                    pairkey = (tuple(ord(c) for c in mo), tuple(ord(c) for c in mq))
                    if pairkey not in catalogue:
                        lbl = f"{marks_label(mo)} → {marks_label(mq)}"
                        bump(novel_types, lbl, f"{key} (on {b!r})")
                        learned.add(pairkey)
                        novel.append(lbl)
                if novel:
                    flags.append(("⚠", "review", "NOVEL mark diff vs quran.com", novel))
        elif qc is not None:
            flags.append(("✗", "B", "missing in quran.com", []))
            hard_fails += 1

        if not args.quiet:
            mark = "✗" if any(f[0] == "✗" for f in flags) else ("⚠" if flags else "✓")
            print(f"  {mark} {key:7} {t}")
            for _, layer, msg, detail in flags:
                print(f"        [{layer}] {msg}")
                for line in detail:
                    print(f"          {line}")

    def show(title, tally):
        if not tally:
            return
        print(f"\n  {title} — {len(tally)} type(s):")
        for k, (count, ex) in sorted(tally.items(), key=lambda kv: -kv[1][0]):
            print(f"    {count:5}×  {k}   (e.g. {ex})")

    show("RASM (letter) differences vs quran.com — HARD FAIL", rasm_types)
    show("NOVEL mark differences vs quran.com (not yet catalogued)", novel_types)

    refs = " + ".join(
        (["golden (exact)"] if golden is not None else [])
        + (["quran.com (rasm + catalogued marks)"] if qc is not None else []))
    print(f"\n  references: {refs or 'NONE'}")
    print(f"  hard fails: {hard_fails}   |   novel mark types: {len(novel_types)}")

    if args.learn and learned:
        save_catalogue(catalogue | learned)
        print(f"\n  --learn: added {len(learned)} mark-convention pair(s) to "
              f"{CATALOGUE.name} (now {len(catalogue | learned)} total).")

    if hard_fails:
        print("\n  RESULT: ✗ letter-level differences — investigate above.")
        return 1
    if novel_types and not args.learn:
        print("\n  RESULT: ⚠ letters OK; novel mark encodings to review "
              "(bless with --learn once confirmed conventions).")
        return 0
    print("\n  RESULT: ✓ matn verified (letters match; marks are known conventions).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
