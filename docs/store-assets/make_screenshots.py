#!/usr/bin/env python3
"""Frame raw device screenshots into a premium, on-brand Play screenshot set.

Brand-green radial (matches the feature graphic) + a Playfair caption + the
screenshot as a floating, rounded, soft-shadowed device. Output 1242x2208 (9:16)
— a Play-safe ratio whose sides satisfy the phone, 7-inch AND 10-inch screenshot
rules, so the same set uploads to all three slots.

Capture the raws first (real device, app installed), e.g. on Android:
    adb exec-out screencap -p > docs/store-assets/screenshots/raw/01-home.png
…navigating the app to each screen. Then run this from the repo root:
    python3 docs/store-assets/make_screenshots.py
Output framed PNGs land in docs/store-assets/screenshots/ ready to upload.
Needs Pillow. (The reminders screen is intentionally omitted here: a *debug*
build injects a dev-only diagnostics card; recapture it from a release build.)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "docs/store-assets/screenshots/raw")
OUT = os.path.join(ROOT, "docs/store-assets/screenshots")
FONT = os.path.join(ROOT, "assets/fonts/PlayfairDisplay-SemiBold.ttf")

W, H = 1242, 2208
CENTER, EDGE = (0x17, 0x66, 0x46), (0x0A, 0x3A, 0x25)
CREAM, GOLD = (245, 235, 210), (216, 166, 46)
STATUS_CROP = 122         # drop the OS status bar
DEV_H, DEV_TOP = 1560, 440

# raw filename (in raw/) -> caption. Output keeps the same filename in OUT.
SHOTS = [
    ("01-home.png",      "Every surah, a tap away"),
    ("02-reading.png",   "Read in authentic Uthmani script"),
    ("03-detailed.png",  "Urdu, Hindi & English translations"),
    ("04-indopak.png",   "Prefer IndoPak? One tap."),
    ("05-audio.png",     "Listen — verse by verse"),
    ("06-prayer.png",    "Prayer times, fully on-device"),
    ("07-customize.png", "Make it yours"),
]


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
    f = ImageFont.truetype(FONT, 66)
    y = 150
    for ln in wrap(d, caption, f, W - 200):
        w = d.textlength(ln, font=f)
        d.text(((W - w) / 2, y), ln, font=f, fill=CREAM)
        y += 84
    d.line([(W / 2 - 70, y + 10), (W / 2 + 70, y + 10)], fill=GOLD, width=3)

    shot = Image.open(src).convert("RGB")
    shot = shot.crop((0, STATUS_CROP, shot.width, shot.height))
    scale = DEV_H / shot.height
    dw, dh = int(shot.width * scale), DEV_H
    shot = shot.resize((dw, dh), Image.LANCZOS).convert("RGBA")
    rad = 44
    mask = Image.new("L", (dw, dh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, dw, dh], rad, fill=255)
    shot.putalpha(mask)

    dx, dy = (W - dw) // 2, DEV_TOP
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [dx, dy + 22, dx + dw, dy + dh + 22], rad, fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    bg = Image.alpha_composite(bg, shadow)
    bg.paste(shot, (dx, dy), shot)
    return bg.convert("RGB")


if __name__ == "__main__":
    for name, cap in SHOTS:
        src = os.path.join(RAW, name)
        if not os.path.exists(src):
            print("skip (missing raw):", name); continue
        frame(src, cap).save(os.path.join(OUT, name))
        print("framed", name, "-", cap)
