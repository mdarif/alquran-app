# Recitation audio pipeline (Alafasy 64 kbps → Cloudflare R2)

One-off tooling to mirror the Mishary Rashid Alafasy per-ayah recitation to the
project's R2 bucket, served at **`https://audio.alquranreader.com`**. The app
streams each verse from `recitation/alafasy_64/{globalId}.mp3`
(see [`lib/core/audio/recitation_source.dart`](../../lib/core/audio/recitation_source.dart)).

**No separate repo, no committed audio.** R2 is object storage — the MP3s are
uploaded straight to the bucket over the S3 API and fronted by a custom domain
(same as the existing `al-tawheed-audio` bucket). They stage locally in the
**gitignored** `tool/audio/staging/` and are never committed.

## Files

| file | what |
|---|---|
| `surah_ayah_counts.py` | 114 per-surah counts (from the app's `quran.db`) + the `SSSAAA → globalId` mapping, with the 2:1 → 8 canary. Source of truth for the rename. |
| `fetch_alafasy_64.py` | download everyayah `Alafasy_64kbps` → `staging/alafasy_64/{globalId}.mp3`; resumable, stdlib-only. |
| `verify.py` | gate before upload: 6236 files, non-empty, valid MP3, canary. |
| `upload_r2.sh` | sync `staging/` → R2 (rclone / aws-s3 / wrangler) with `audio/mpeg` + 1-year immutable headers. |

## The numbering (get it right)

The app addresses verses by a **global 1..6236 id** — a running index where
Al-Fatihah 1:1 = 1 and Al-Baqarah 2:1 = 8 (Fatiha's 7 verses precede it; Bismillah
is not a separate ayah). This matches the app's `quran.db` (`ayahs.id`), from which
`surah_ayah_counts.py` is exported. everyayah names files `SSSAAA.mp3`, so the fetch
renames `002001.mp3 → 8.mp3`. **Get it wrong and every verse plays the wrong audio**
— the app has a numbering-canary test, and `verify.py` re-checks it (`8.mp3 → 2:1`).

## Run

```bash
# from the app repo root
python3 tool/audio/fetch_alafasy_64.py     # ~6236 files, ~300 MB → tool/audio/staging/, resumable
python3 tool/audio/verify.py               # must print "Ready for upload_r2.sh"
R2_BUCKET=al-quran-audio bash tool/audio/upload_r2.sh
# then attach audio.alquranreader.com to the bucket (R2 > bucket > Custom Domains)
```

Spot-check one surah first: `python3 tool/audio/fetch_alafasy_64.py --surah 1`.

## Notes

- **Immutable** — audio never changes; the 1-year cache is safe. The set is
  complete (6236 verses).
- **Adding a reciter later** — stage under `staging/<reciter>_<bitrate>/` and upload
  to `recitation/<reciter>_<bitrate>/` (matching the app's per-reciter cache
  namespace). Don't touch `alafasy_64/`.
- **Licensing** — Alafasy attribution stays visible in the app (Credits + player);
  sign-off is tracked with the translations/fonts sweep (`../alquran-data/HANDOFF.md`).
