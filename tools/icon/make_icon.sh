#!/usr/bin/env bash
# Build the Al Quran launcher-icon masters in assets/icon/ from scratch.
#
# The icon is a wordmark: اقرأ ("Read" — the first revealed word, Surah
# al-'Alaq), set in the bundled KFGQPC Uthmanic Hafs face, gold on deep green.
#
# Pipeline: HarfBuzz (uharfbuzz) shapes the Arabic and fontTools emits the glyph
# outlines as a vector path; ImageMagick composes the gradient ground, the
# gold-gradient fill through a path mask, and a soft shadow.
#
# Requires: python3 with `uharfbuzz` + `fonttools`, and ImageMagick (`convert`).
# After running, regenerate the per-platform icons with:
#   dart run flutter_launcher_icons
set -euo pipefail
cd "$(dirname "$0")/../.."

FONT="assets/fonts/UthmanicHafs1-Ver18.ttf"
WORD="اقرأ"
S=1024
OUT="assets/icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# 1) shaped glyph outlines -> ImageMagick draw path (centred, fit to 0.46 of canvas)
python3 tools/icon/gen_path.py "$FONT" "$WORD" "$S" 0.46 > "$TMP/glyphs.path"
printf "fill white path '" > "$TMP/word.mvg"
cat "$TMP/glyphs.path" >> "$TMP/word.mvg"
printf "'" >> "$TMP/word.mvg"

# 2) green radial ground (lighter centre)  3) white word mask  4) gold gradient
convert -size ${S}x${S} radial-gradient:'#176646'-'#0A3A25' "$TMP/bg.png"
convert -size ${S}x${S} xc:black -draw @"$TMP/word.mvg" "$TMP/mask.png"
convert -size ${S}x${S} gradient:'#F6E6AC'-'#C68F1E' "$TMP/gold.png"

# 5) gold word (gradient through the mask)  6) soft drop shadow
convert "$TMP/gold.png" "$TMP/mask.png" -alpha off -compose CopyOpacity -composite "$TMP/word_gold.png"
convert "$TMP/mask.png" -channel A -blur 0x9 +channel -background black -alpha shape \
        -fill black -colorize 100 "$TMP/shadow.png"
convert "$TMP/shadow.png" -background none -alpha set -channel A -evaluate multiply 0.45 +channel "$TMP/shadow2.png"

# masters: full (iOS + legacy), adaptive background, adaptive foreground (transparent)
convert "$TMP/bg.png" \( "$TMP/shadow2.png" -geometry +0+10 \) -composite \
        "$TMP/word_gold.png" -composite -depth 8 "$OUT/icon.png"
convert "$TMP/bg.png" -depth 8 "$OUT/icon_background.png"
convert -size ${S}x${S} xc:none \( "$TMP/shadow2.png" -geometry +0+10 \) -composite \
        "$TMP/word_gold.png" -composite -depth 8 "$OUT/icon_foreground.png"

echo "Wrote $OUT/icon.png, icon_background.png, icon_foreground.png"
echo "Now run: dart run flutter_launcher_icons"
