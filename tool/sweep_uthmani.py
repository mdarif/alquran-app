#!/usr/bin/env python3
"""Sweep every surah: compare our Uthmani text to quran.com's QPC-Hafs text
(text_qpc_hafs — what the website renders) and categorise the differences.

Per surah we count:
  • kashida_extra  — U+0640 carriers our build grafted that quran.com lacks
                     (the cosmetic over-stretch; the systematic fix target)
  • real_diffs     — ayahs that differ at the READING level after normalising
                     (kashida/space/mark-order folded out) — the rare ones that
                     need human eyes.

Writes tool/.cache/sweep_results.json and prints a summary + the full real-diff
list. Cached per surah, so re-runs are instant/offline.
"""

import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_uthmani as vu

TAT = "ـ"
OUT = vu.CACHE_DIR / "sweep_results.json"


def real_diff(o: str, q: str) -> bool:
    co, cq = vu.clusters(o), vu.clusters(q)
    if [b for b, _ in co] != [b for b, _ in cq]:
        return True
    return any(mo != mq for (_, mo), (_, mq) in zip(co, cq))


def main() -> int:
    con = sqlite3.connect(f"file:{vu.APP_DB}?mode=ro", uri=True)
    results = {}
    all_real = []
    print(f"{'surah':>5} {'ayahs':>5} {'kashida+':>8} {'ayahs+':>6} {'real':>5}")
    for s in range(1, 115):
        ours = {a: t for a, t in con.execute(
            "SELECT ayah_number,text_arabic_uthmani FROM ayahs WHERE surah_id=? "
            "ORDER BY ayah_number", (s,)).fetchall()}
        try:
            qc = vu.load_qurancom(s, refresh=False)
        except Exception as e:  # noqa: BLE001
            print(f"{s:>5}  fetch error: {e}")
            continue
        extra = sum(max(0, ours[a].count(TAT) - qc.get(a, "").count(TAT)) for a in ours)
        ayahs_extra = sum(1 for a in ours if ours[a].count(TAT) > qc.get(a, "").count(TAT))
        real = [a for a in sorted(ours) if a in qc and real_diff(ours[a], qc[a])]
        results[s] = {"ayahs": len(ours), "kashida_extra": extra,
                      "ayahs_with_extra": ayahs_extra, "real_diffs": real}
        for a in real:
            all_real.append(f"{s}:{a}")
        flag = " <-- REAL" if real else ""
        print(f"{s:>5} {len(ours):>5} {extra:>8} {ayahs_extra:>6} {len(real):>5}{flag}")

    tot_extra = sum(r["kashida_extra"] for r in results.values())
    tot_ayahs_extra = sum(r["ayahs_with_extra"] for r in results.values())
    print("\n=== TOTALS ===")
    print(f"  surahs swept            : {len(results)}/114")
    print(f"  total extra kashidas    : {tot_extra}  (across {tot_ayahs_extra} ayahs)")
    print(f"  reading-level diffs     : {len(all_real)} ayahs -> {all_real}")
    OUT.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n  wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
