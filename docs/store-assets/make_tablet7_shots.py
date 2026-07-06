#!/usr/bin/env python3
"""Frame ACTUAL 7-inch tablet captures (portrait) into Play-ready screenshots.

Companion to make_screenshots.py (phone) and make_tablet_shots.py (10-inch
landscape). These come from a real 7-inch tablet (Nexus 7, 1200x1920 portrait)
running the app, so the reading page is a genuine tablet Mushaf column — not a
phone shot reframed. Same brand frame: deep-green radial + Playfair caption +
rounded device inset + soft shadow. Portrait 1242x2208 canvas (Play-valid 7").

Raws live in screenshots/raw-tablet7/ ; framed output -> screenshots/tablet-7in/.
Override the base dir to keep an older set intact, e.g.
    SCREENSHOTS_DIR=docs/store-assets/screenshots-v1.1 python3 make_tablet7_shots.py
Needs Pillow.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(HERE, "..", ".."))
BASE = os.environ.get("SCREENSHOTS_DIR", os.path.join(HERE, "screenshots"))
if not os.path.isabs(BASE):
    BASE = os.path.join(APP, BASE)
RAW = os.path.join(BASE, "raw-tablet7")
OUT = os.path.join(BASE, "tablet-7in")
FONT = os.path.join(APP, "assets/fonts/PlayfairDisplay-SemiBold.ttf")

W, H = 1242, 2208
K = W / 1242
CENTER, EDGE = (0x17, 0x66, 0x46), (0x0A, 0x3A, 0x25)
CREAM, GOLD = (245, 235, 210), (216, 166, 46)
STATUS_CROP = 52           # the 7-inch (1200px-wide) status bar, in raw px
DEV_H, DEV_TOP = int(1560 * K), int(440 * K)

CAPTIONS = {
    "01-home.png": "Every surah, a tap away",
    "19-search.png": "Find a surah — or jump to a verse",
    "02-reading.png": "The Mushaf page, on your tablet",
    "14-detailed.png": "Urdu, Hindi & English, together",
    "17-size.png": "Your script, size & language",
}
ORDER = ["01-home.png", "19-search.png", "02-reading.png",
         "14-detailed.png", "17-size.png"]


def brand_bg():
    img = Image.new("RGB", (W, H), EDGE)
    d = ImageDraw.Draw(img)
    cx, cy = W // 2, int(H * 0.40)
    maxr = int(max(math.hypot(cx, cy), math.hypot(W - cx, cy),
                   math.hypot(cx, H - cy), math.hypot(W - cx, H - cy)))
    for r in range(maxr, 0, -1):
        t = r / maxr
        col = tuple(int(EDGE[i] * t + CENTER[i] * (1 - t)) for i in range(3))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    return img.convert("RGBA")


def wrap(draw, text, font, maxw):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= maxw:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur:
        lines.append(cur)
    return lines


def frame(src, caption):
    bg = brand_bg()
    d = ImageDraw.Draw(bg)
    f = ImageFont.truetype(FONT, int(66 * K))
    y = int(150 * K)
    for ln in wrap(d, caption, f, W - int(200 * K)):
        w = d.textlength(ln, font=f)
        d.text(((W - w) / 2, y), ln, font=f, fill=CREAM)
        y += int(84 * K)
    rw = int(70 * K)
    d.line([(W / 2 - rw, y + 10 * K), (W / 2 + rw, y + 10 * K)],
           fill=GOLD, width=max(2, int(3 * K)))

    shot = Image.open(src).convert("RGB")
    shot = shot.crop((0, STATUS_CROP, shot.width, shot.height))
    scale = DEV_H / shot.height
    dw, dh = int(shot.width * scale), DEV_H
    shot = shot.resize((dw, dh), Image.LANCZOS).convert("RGBA")
    rad = int(44 * K)
    mask = Image.new("L", (dw, dh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, dw, dh], rad, fill=255)
    shot.putalpha(mask)

    off = int(22 * K)
    dx, dy = (W - dw) // 2, DEV_TOP
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [dx, dy + off, dx + dw, dy + dh + off], rad, fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(34 * K)))
    bg = Image.alpha_composite(bg, shadow)
    bg.paste(shot, (dx, dy), shot)
    return bg.convert("RGB")


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
        stem = raw.split("-", 1)[1].replace(".png", "")
        frame(p, CAPTIONS[raw]).save(os.path.join(OUT, f"{pos}-{stem}.png"))
        print(f"  tablet-7in/{pos}-{stem}.png  -  {CAPTIONS[raw]}")


if __name__ == "__main__":
    main()
