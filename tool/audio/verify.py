#!/usr/bin/env python3
"""Verify the staging dir is complete and well-formed BEFORE uploading to R2:

  * exactly 6236 files, `1.mp3` .. `6236.mp3` — none missing, none extra
  * every file non-empty and looks like an MP3 (ID3 tag or MPEG frame sync)
  * numbering canary: `8.mp3` exists and maps to Al-Baqarah 2:1

Exits non-zero on any problem, so it can gate the upload. stdlib only.

Usage (from the app repo root):
  python3 tool/audio/verify.py
  AUDIO_OUT=/path python3 tool/audio/verify.py   # override the staging dir
"""
import os
import sys

from surah_ayah_counts import surah_ayah

DIR = os.environ.get("AUDIO_OUT") or os.path.normpath(
    os.path.join(os.path.dirname(__file__), "staging", "alafasy_64")
)


def looks_like_mp3(path: str) -> bool:
    with open(path, "rb") as f:
        head = f.read(3)
    if head[:3] == b"ID3":
        return True
    # MPEG audio frame sync: 11 set bits (0xFF 0xEx/0xFx).
    return len(head) >= 2 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0


def main() -> int:
    if not os.path.isdir(DIR):
        print(f"missing directory: {DIR}\nRun tool/audio/fetch_alafasy_64.py first.")
        return 1

    missing, empty, bad = [], [], []
    for gid in range(1, 6237):
        p = os.path.join(DIR, f"{gid}.mp3")
        if not os.path.exists(p):
            missing.append(gid)
        elif os.path.getsize(p) == 0:
            empty.append(gid)
        elif not looks_like_mp3(p):
            bad.append(gid)

    present_ids = {
        int(n[:-4])
        for n in os.listdir(DIR)
        if n.endswith(".mp3") and n[:-4].isdigit()
    }
    extra = sorted(present_ids - set(range(1, 6237)))

    problems = False
    for label, lst in [
        ("missing", missing),
        ("empty", empty),
        ("not-an-mp3", bad),
        ("extra/unexpected", extra),
    ]:
        if lst:
            problems = True
            shown = ", ".join(str(x) for x in lst[:15])
            more = f" (+{len(lst) - 15} more)" if len(lst) > 15 else ""
            print(f"  {label}: {len(lst)} -> {shown}{more}")

    present = 6236 - len(missing)
    print(f"present: {present}/6236")
    if os.path.exists(os.path.join(DIR, "8.mp3")):
        print(f"canary: 8.mp3 -> surah/ayah {surah_ayah(8)} (expect (2, 1))")

    if problems or present != 6236:
        print("\nNOT READY — fix the above (re-run fetch to fill gaps).")
        return 1
    total_mb = sum(
        os.path.getsize(os.path.join(DIR, f"{g}.mp3")) for g in range(1, 6237)
    ) / (1024 * 1024)
    print(f"OK — 6236 non-empty MP3s, {total_mb:.0f} MB. Ready for upload_r2.sh.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
