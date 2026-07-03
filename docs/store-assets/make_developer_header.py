#!/usr/bin/env python3
"""Google Play *developer page* header (Al Marfa Technologies).

4096x2304 (16:9), 24-bit PNG (no alpha) — upload at Play Console -> Developer
account -> Developer profile -> Header image. Deep-green brand radial + a
stacked Playfair headline + the gold Q mark. Run from the repo root:
    python3 docs/store-assets/make_developer_header.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "assets/fonts/PlayfairDisplay-SemiBold.ttf")
LOGO = os.path.join(ROOT, "assets/icon/splash_logo.png")
OUT = os.path.join(ROOT, "docs/store-assets/play-developer-header-4096x2304.png")

W, H = 4096, 2304
CENTER, EDGE = (0x17, 0x66, 0x46), (0x0A, 0x3A, 0x25)
CREAM, GOLD, SUBGOLD = (245, 235, 210), (216, 166, 46), (210, 180, 120)
HEADLINE = ["Read.", "Reflect.", "Remember."]
SUBLINE = "By Al Marfa Technologies"

# radial-gradient background (offset left so the headline sits on the brighter side)
img = Image.new("RGB", (W, H), EDGE)
d = ImageDraw.Draw(img)
cx, cy = int(W * 0.40), int(H * 0.46)
maxr = int(max(math.hypot(cx, cy), math.hypot(W - cx, cy),
               math.hypot(cx, H - cy), math.hypot(W - cx, H - cy)))
for r in range(maxr, 0, -1):
    t = r / maxr
    col = tuple(int(EDGE[i] * t + CENTER[i] * (1 - t)) for i in range(3))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

# gold Q mark, right side, vertically centred
q = Image.open(LOGO).convert("RGBA")
q.thumbnail((1480, 1480), Image.LANCZOS)
img.paste(q, (2560, (H - q.height) // 2), q)

# stacked headline, left, vertically centred as a block
d = ImageDraw.Draw(img)
big = ImageFont.truetype(FONT, 300)
sub = ImageFont.truetype(FONT, 82)
x, step = 360, 330
top = (H - step * len(HEADLINE)) // 2 - 40
y = top
for ln in HEADLINE:
    bb = d.textbbox((0, 0), ln, font=big)
    d.text((x, y - bb[1]), ln, font=big, fill=CREAM)
    y += step

# gold rule + subline
ry = y + 26
d.line([(x + 6, ry), (x + 300, ry)], fill=GOLD, width=6)
d.text((x, ry + 34), SUBLINE, font=sub, fill=SUBGOLD)

img.save(OUT)  # RGB, no alpha channel
print("saved", OUT, img.size)
