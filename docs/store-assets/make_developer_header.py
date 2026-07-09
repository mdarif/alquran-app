#!/usr/bin/env python3
"""Google Play *developer page* header (Al Marfa Technologies).

4096x2304 (16:9), 24-bit PNG (no alpha) — upload at Play Console -> Developer
account -> Developer profile -> Header image. Deep-green brand radial +
stacked Playfair headline + a tilted phone showing the Al Quran reading screen.
Run from the repo root:  python3 docs/store-assets/make_developer_header.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "assets/fonts/PlayfairDisplay-SemiBold.ttf")
SHOT = os.path.join(ROOT, "docs/store-assets/screenshots/raw/02-reading.png")
OUT = os.path.join(ROOT, "docs/store-assets/play-developer-header-4096x2304.png")

W, H = 4096, 2304
CENTER, EDGE = (0x17, 0x66, 0x46), (0x0A, 0x3A, 0x25)
CREAM, GOLD, SUBGOLD = (245, 235, 210), (216, 166, 46), (210, 180, 120)
HEAD = ["Simple.", "Beautiful.", "Beneficial."]
SUB = "Al Marfa Technologies"


def radial(w, h, cxf, cyf):
    img = Image.new("RGB", (w, h), EDGE)
    d = ImageDraw.Draw(img)
    cx, cy = int(w * cxf), int(h * cyf)
    maxr = int(max(math.hypot(cx, cy), math.hypot(w - cx, cy),
                   math.hypot(cx, h - cy), math.hypot(w - cx, h - cy)))
    for r in range(maxr, 0, -1):
        t = r / maxr
        col = tuple(int(EDGE[i] * t + CENTER[i] * (1 - t)) for i in range(3))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    return img


def rounded_alpha(w, h, rad):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w, h], rad, fill=255)
    return m


img = radial(W, H, 0.34, 0.5).convert("RGBA")

# ---- phone mockup (right, tilted, bleeding off the top) ----
shot = Image.open(SHOT).convert("RGB").crop((0, 122, 1272, 2800))
screen_h = 2000
sc = screen_h / shot.height
sw, sh = int(shot.width * sc), screen_h
shot = shot.resize((sw, sh), Image.LANCZOS).convert("RGBA")
srad = 60
shot.putalpha(rounded_alpha(sw, sh, srad))

bez = 24                                   # phone bezel
bw, bh = sw + 2 * bez, sh + 2 * bez
body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
ImageDraw.Draw(body).rounded_rectangle([0, 0, bw, bh], srad + bez, fill=(18, 22, 20, 255))
body.alpha_composite(shot, (bez, bez))

phone = body.rotate(7, expand=True, resample=Image.BICUBIC)   # top leans right
pw, ph = phone.size
cxp, cyp = 3060, 1090                        # phone centre (bleeds off the top)
px, py = int(cxp - pw / 2), int(cyp - ph / 2)

# soft drop shadow from the phone silhouette
sil = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
sil.putalpha(phone.split()[3].point(lambda a: int(a * 0.5)))
black = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
black.paste((0, 0, 0), (0, 0), sil)
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
shadow.alpha_composite(black, (px + 34, py + 52))
shadow = shadow.filter(ImageFilter.GaussianBlur(48))
img = Image.alpha_composite(img, shadow)
img.alpha_composite(phone, (px, py))

# ---- headline (left, WHOLE group vertically centred) ----
# The Play developer-page header displays as a wide banner and crops the top &
# bottom of this 16:9 art, so the headline must sit well inside the centre band.
# Centre the entire group (3 lines + gold rule + sub-line), not just the lines,
# and keep it compact enough that nothing rides the crop edge.
d = ImageDraw.Draw(img)
big = ImageFont.truetype(FONT, 212)
sub = ImageFont.truetype(FONT, 66)
x, step = 340, 248
rule_gap, sub_gap = 46, 30                 # line -> rule, rule -> sub
grp_h = step * len(HEAD) + rule_gap + 6 + sub_gap + sub.size
top = (H - grp_h) // 2
y = top
for ln in HEAD:
    bb = d.textbbox((0, 0), ln, font=big)
    d.text((x, y - bb[1]), ln, font=big, fill=CREAM)
    y += step
ry = y + rule_gap
d.line([(x + 6, ry), (x + 288, ry)], fill=GOLD, width=6)
d.text((x, ry + sub_gap), SUB, font=sub, fill=SUBGOLD)

img.convert("RGB").save(OUT)   # no alpha
print("saved", OUT, img.size)
