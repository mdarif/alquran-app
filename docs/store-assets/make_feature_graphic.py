#!/usr/bin/env python3
"""Generate the 1024x500 Google Play feature graphic from brand assets.

Deep-green brand radial + the gold Q mark + Playfair wordmark + tagline.
Run from the repo root:  python3 docs/store-assets/make_feature_graphic.py
Output: docs/store-assets/play-feature-1024x500.png

Reusable for a sibling app: swap LOGO/FONT/colours/wordmark/tagline below.
Needs Pillow (`pip install pillow`). Note: the bundled ImageMagick has no
FreeType, so it can't draw the text — Pillow is used instead.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

W, H = 1024, 500
CENTER = (0x17, 0x66, 0x46)   # brand background center (brand-tokens.json)
EDGE   = (0x0A, 0x3A, 0x25)   # brand background edge
CREAM  = (245, 235, 210)      # wordmark
GOLD   = (216, 166, 46)       # brand mark mid-gold (#D8A62E) — rule
TAGLINE_FILL = (210, 180, 120)

LOGO = os.path.join(ROOT, "assets/icon/splash_logo.png")
FONT = os.path.join(ROOT, "assets/fonts/PlayfairDisplay-SemiBold.ttf")
OUT  = os.path.join(ROOT, "docs/store-assets/play-feature-1024x500.png")
WORDMARK, TAGLINE = "Al Quran", "Read.  Reflect.  Remember."

# radial-gradient background (center brand green -> darker edge)
img = Image.new("RGB", (W, H), EDGE)
d = ImageDraw.Draw(img)
cx, cy = 512, 210
maxr = int(max(math.hypot(cx, cy), math.hypot(W - cx, cy),
               math.hypot(cx, H - cy), math.hypot(W - cx, H - cy)))
for r in range(maxr, 0, -1):
    t = r / maxr
    col = tuple(int(EDGE[i] * t + CENTER[i] * (1 - t)) for i in range(3))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

# gold Q mark, left, vertically centred
q = Image.open(LOGO).convert("RGBA")
q.thumbnail((430, 430), Image.LANCZOS)
img.paste(q, (70, (H - q.height) // 2), q)

# wordmark + rule + tagline, right block, vertically centred as a group
d = ImageDraw.Draw(img)
big, small = ImageFont.truetype(FONT, 118), ImageFont.truetype(FONT, 33)
tx = 470
wb = d.textbbox((0, 0), WORDMARK, font=big)
sb = d.textbbox((0, 0), TAGLINE, font=small)
w_h, s_h, gap = wb[3] - wb[1], sb[3] - sb[1], 26
top = (H - (w_h + gap + s_h)) // 2
d.text((tx, top - wb[1]), WORDMARK, font=big, fill=CREAM)
rule_y = top + w_h + gap // 2
d.line([(tx + 3, rule_y), (tx + 300, rule_y)], fill=GOLD, width=2)
d.text((tx, top + w_h + gap - sb[1]), TAGLINE, font=small, fill=TAGLINE_FILL)

img.save(OUT)
print("saved", OUT, img.size)
