#!/usr/bin/env bash
# Upload the staged recitation MP3s to Cloudflare R2 under recitation/alafasy_64/,
# with the headers the app relies on. Run from the app repo root, AFTER
# `python3 tool/audio/verify.py` passes.
#
# Prereqs (you already run R2 — cf. the al-tawheed-audio bucket):
#   1. A bucket for this app, e.g. `al-quran-audio` (R2 > Create bucket).
#   2. An S3 API token (R2 > Manage R2 API Tokens) → access key + secret.
#   3. Your account id → endpoint https://<ACCOUNT_ID>.r2.cloudflarestorage.com
#      (shown on the R2 overview page).
#   4. After the first upload, attach the custom domain `audio.alquranreader.com`
#      to the bucket (bucket > Settings > Custom Domains), so
#      https://audio.alquranreader.com/recitation/alafasy_64/{id}.mp3 resolves.
#
# Objects get Content-Type audio/mpeg + a 1-year immutable cache (files never
# change). R2 serves HTTP range requests natively — what just_audio's
# LockCachingAudioSource + the in-app scrubber need.
set -euo pipefail

BUCKET="${R2_BUCKET:-al-quran-audio}"
PREFIX="recitation/alafasy_64"
SRC="${AUDIO_OUT:-tool/audio/staging/alafasy_64}"

if [[ ! -d "$SRC" ]]; then
  echo "No staging dir $SRC — run tool/audio/fetch_alafasy_64.py first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Option 1 — rclone  (recommended for 6236 files: parallel, resumable)
# ---------------------------------------------------------------------------
# One-time: `rclone config` → new remote name=r2, storage=s3, provider=Cloudflare,
#   access_key_id / secret_access_key from the R2 token,
#   endpoint=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
rclone copy "$SRC" "r2:${BUCKET}/${PREFIX}" \
  --header-upload "Content-Type: audio/mpeg" \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --transfers 16 --checkers 32 --progress

# ---------------------------------------------------------------------------
# Option 2 — aws s3 (S3-compatible client against the R2 endpoint)
# ---------------------------------------------------------------------------
#   export AWS_ACCESS_KEY_ID=<R2 key> AWS_SECRET_ACCESS_KEY=<R2 secret>
#   aws s3 cp "$SRC" "s3://${BUCKET}/${PREFIX}" --recursive \
#     --endpoint-url "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" \
#     --content-type "audio/mpeg" \
#     --cache-control "public, max-age=31536000, immutable"

# ---------------------------------------------------------------------------
# Option 3 — wrangler (no extra tools; one object at a time, slower)
# ---------------------------------------------------------------------------
#   for f in "$SRC"/*.mp3; do
#     wrangler r2 object put "${BUCKET}/${PREFIX}/$(basename "$f")" \
#       --file "$f" --content-type "audio/mpeg" \
#       --cache-control "public, max-age=31536000, immutable"
#   done

echo "Done. Smoke test:"
echo "  curl -sI https://audio.alquranreader.com/${PREFIX}/8.mp3 | grep -iE 'content-type|cache-control|accept-ranges'"
