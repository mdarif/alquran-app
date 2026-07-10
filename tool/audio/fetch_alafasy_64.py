#!/usr/bin/env python3
"""Download the everyayah.com **Alafasy_64kbps** per-ayah set into a local staging
dir as `{globalId}.mp3` — the key layout the app + R2 serve
(`recitation/alafasy_64/{globalId}.mp3`, see lib/core/audio/recitation_source.dart).

The staging dir is gitignored: these files are NOT committed. They exist only to be
uploaded to Cloudflare R2 (see upload_r2.sh). R2 — not git — is the store.

Why this source: native 64 kbps mono (NOT a lossy 128->64 re-encode), the canonical
per-ayah Mishary Rashid Alafasy set, 6236 files. everyayah names files `SSSAAA.mp3`
(per-surah); we rename each to the app's global 1..6236 id (Fatiha 1:1 = 1,
Baqarah 2:1 = 8) so only the base URL changed on the app side.

Resumable + idempotent: skips files already present and non-empty; writes via a
`.part` temp + atomic rename. stdlib only — no pip installs.

Usage (from the app repo root):
  python3 tool/audio/fetch_alafasy_64.py                # all 6236 -> tool/audio/staging/alafasy_64/
  python3 tool/audio/fetch_alafasy_64.py --surah 1      # one surah (spot check)
  AUDIO_OUT=/path python3 tool/audio/fetch_alafasy_64.py   # override the staging dir
"""
import argparse
import os
import sys
import time
import urllib.request

from surah_ayah_counts import AYAH_COUNTS, all_pairs, global_id

BASE = "https://everyayah.com/data/Alafasy_64kbps"
OUT = os.environ.get("AUDIO_OUT") or os.path.normpath(
    os.path.join(os.path.dirname(__file__), "staging", "alafasy_64")
)


def src_url(surah: int, ayah: int) -> str:
    return f"{BASE}/{surah:03d}{ayah:03d}.mp3"


def dest_path(gid: int) -> str:
    return os.path.join(OUT, f"{gid}.mp3")


def fetch_one(surah: int, ayah: int, gid: int, retries: int = 4):
    dst = dest_path(gid)
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return gid, "skip", 0
    url = src_url(surah, ayah)
    tmp = dst + ".part"
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "alquran-audio/1.0 (+audio mirror)"}
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            if not data:
                raise OSError("empty body")
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, dst)
            return gid, "ok", len(data)
        except Exception as e:  # network / HTTP — retry with backoff
            last = e
            time.sleep(1.5 * (attempt + 1))
    if os.path.exists(tmp):
        try:
            os.remove(tmp)
        except OSError:
            pass
    return gid, f"FAIL {last}", 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--surah", type=int, help="fetch only this surah (1..114)")
    ap.add_argument("--workers", type=int, default=6, help="parallel downloads")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)

    if args.surah:
        pairs = [
            (args.surah, a, global_id(args.surah, a))
            for a in range(1, AYAH_COUNTS[args.surah - 1] + 1)
        ]
    else:
        pairs = list(all_pairs())

    from concurrent.futures import ThreadPoolExecutor, as_completed

    total = len(pairs)
    ok = skip = fail = 0
    fails = []
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = [ex.submit(fetch_one, s, a, g) for (s, a, g) in pairs]
        done = 0
        for fut in as_completed(futs):
            gid, status, _ = fut.result()
            done += 1
            if status == "ok":
                ok += 1
            elif status == "skip":
                skip += 1
            else:
                fail += 1
                fails.append((gid, status))
            if done % 50 == 0 or done == total:
                dt = time.time() - t0
                print(
                    f"\r{done}/{total}  ok={ok} skip={skip} fail={fail}  {dt:.0f}s",
                    end="",
                    flush=True,
                )
    print(f"\nstaging dir: {OUT}")

    if fails:
        print(f"{len(fails)} FAILED — re-run to retry (it resumes):")
        for gid, st in sorted(fails)[:20]:
            print(f"  {gid}.mp3  {st}")
        return 1
    print("done. Next: python3 tool/audio/verify.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
