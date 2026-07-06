#!/usr/bin/env python3
"""Frame ACTUAL 10-inch tablet captures into Play-ready landscape shots.

Unlike make_screenshots.py (which frames portrait phone captures), these come
from a real 10-inch tablet (2560x1600, Pixel Tablet emulator) running the app —
the reading page fills the width like an open Mushaf. Same brand frame: deep
green radial + Playfair caption + rounded device inset + soft shadow.

Raws live in screenshots/raw-tablet/ ; framed output → screenshots/tablet-10in/.
Run: python3 docs/store-assets/make_tablet_shots.py  (needs Pillow)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(HERE, "..", ".."))
# Base dir; override to frame a new set while keeping an older one intact, e.g.
# SCREENSHOTS_DIR=docs/store-assets/screenshots-v1.1 python3 make_tablet_shots.py
BASE = os.environ.get("SCREENSHOTS_DIR", os.path.join(HERE, "screenshots"))
if not os.path.isabs(BASE):
    BASE = os.path.join(APP, BASE)
RAW = os.path.join(BASE, "raw-tablet")
OUT = os.path.join(BASE, "tablet-10in")
FONT = os.path.join(APP, "assets", "fonts", "PlayfairDisplay-SemiBold.ttf")

# Landscape canvas (16:10, Play-valid for 10-inch tablets).
W, H = 2560, 1600
CENTER = (0x17, 0x66, 0x46)   # #176646
EDGE = (0x0A, 0x3A, 0x25)     # #0A3A25
CREAM = (245, 235, 210)
GOLD = (216, 166, 46)
STATUS_CROP = 48              # trim the tablet status bar (px, at 2560x1600)
SHOT_W = 2040                 # framed screenshot width on the canvas
RADIUS = 40

CAPTIONS = {
    "tab-reading.png": "The whole page — beautifully, on tablet",
    "tab-detailed.png": "Arabic with translation, side by side",
    "tab-search.png": "Find a surah — or jump to a verse",
}
ORDER = ["tab-reading.png", "tab-detailed.png", "tab-search.png"]


def brand_bg():
    img = Image.new("RGB", (W, H), EDGE)
    px = img.load()
    cx, cy = W / 2, H * 0.42
    maxd = (W ** 2 + H ** 2) ** 0.5
    for y in range(H):
        for x in range(0, W, 2):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd * 1.7
            d = min(1.0, d)
            c = tuple(int(CENTER[i] + (EDGE[i] - CENTER[i]) * d) for i in range(3))
            px[x, y] = c
            if x + 1 < W:
                px[x + 1, y] = c
    return img


def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, im.size[0], im.size[1]], radius=r, fill=255)
    im.putalpha(mask)
    return im


def frame(raw_path, caption):
    img = brand_bg()
    draw = ImageDraw.Draw(img)

    # Caption (Playfair), centered near the top.
    f = ImageFont.truetype(FONT, 76)
    tb = draw.textbbox((0, 0), caption, font=f)
    tw = tb[2] - tb[0]
    draw.text(((W - tw) / 2, 80), caption, font=f, fill=CREAM)
    # gold rule under caption
    ry = 80 + (tb[3] - tb[1]) + 44
    draw.rectangle([(W - 150) / 2, ry, (W + 150) / 2, ry + 4], fill=GOLD)

    # Screenshot: crop status bar, scale to SHOT_W, round corners.
    shot = Image.open(raw_path).convert("RGB")
    w, h = shot.size
    shot = shot.crop((0, STATUS_CROP, w, h))
    sw, sh = shot.size
    new_h = int(sh * SHOT_W / sw)
    shot = shot.resize((SHOT_W, new_h), Image.LANCZOS)
    shot = rounded(shot, RADIUS)

    # Soft drop shadow.
    dx = (W - SHOT_W) // 2
    dy = ry + 70
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = Image.new("RGBA", shot.size, (0, 0, 0, 150))
    sd.putalpha(shot.split()[3].point(lambda a: 150 if a > 0 else 0))
    shadow.paste(sd, (dx, dy + 16), sd)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img.paste(Image.alpha_composite(img.convert("RGBA"), shadow).convert("RGB"), (0, 0))
    img.paste(shot, (dx, dy), shot)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    for pos, raw in enumerate(ORDER, 1):
        p = os.path.join(RAW, raw)
        if not os.path.exists(p):
            print(f"  (skip {raw} — not captured)")
            continue
        stem = raw.replace("tab-", "").replace(".png", "")
        frame(p, CAPTIONS[raw]).save(os.path.join(OUT, f"{pos}-{stem}.png"))
        print(f"  tablet-10in/{pos}-{stem}.png  -  {CAPTIONS[raw]}")


if __name__ == "__main__":
    main()
