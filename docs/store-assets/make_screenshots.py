#!/usr/bin/env python3
"""Frame raw device screenshots into premium, on-brand Play screenshot sets.

Brand-green radial (matches the feature graphic) + a Playfair caption + the
screenshot as a floating, rounded, soft-shadowed device. Output 1242x2208 (9:16)
— a Play-safe ratio whose sides satisfy the phone, 7-inch AND 10-inch slots.

Play gives THREE separate screenshot slots (phone / 7-inch / 10-inch), up to 8
each. Rather than duplicate one set everywhere, we split a 12-screen pool: the
PHONE set carries the headline features; the TABLET set (used for BOTH 7-inch
and 10-inch) surfaces the extras (audio, reminders, About, large-text), so a
browser sees more of the app. Outputs land in screenshots/phone/ and
screenshots/tablet/ in display order.

Capture raws first (real device, app installed), e.g. on Android:
    adb exec-out screencap -p > docs/store-assets/screenshots/raw/01-home.png
Then run from the repo root:  python3 docs/store-assets/make_screenshots.py
Needs Pillow. (Reminders is de-debugged separately — see 08-reminders in raw/.)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Output/raw base; override to keep an older set intact while framing a new one,
# e.g. SCREENSHOTS_DIR=docs/store-assets/screenshots-v1.1 python3 make_screenshots.py
BASE = os.environ.get(
    "SCREENSHOTS_DIR", os.path.join(ROOT, "docs/store-assets/screenshots")
)
if not os.path.isabs(BASE):
    BASE = os.path.join(ROOT, BASE)
RAW = os.path.join(BASE, "raw")
FONT = os.path.join(ROOT, "assets/fonts/PlayfairDisplay-SemiBold.ttf")

W, H = 1242, 2208
K = W / 1242               # layout scale (bump W/H proportionally if Play ever
CENTER, EDGE = (0x17, 0x66, 0x46), (0x0A, 0x3A, 0x25)   # rejects "too small to crop")
CREAM, GOLD = (245, 235, 210), (216, 166, 46)
STATUS_CROP = 122          # drop the OS status bar (on the raw, in raw px)
DEV_H, DEV_TOP = int(1560 * K), int(440 * K)

# caption per raw screen (in raw/)
CAPTIONS = {
    # Shared by the phone slots 1–2 and the tablet (7") breadth set.
    "01-home.png":      "Every surah, a tap away",
    "02-reading.png":   "Read in authentic Uthmani script",
    # Tablet (7") breadth set only.
    "04-detailed.png":  "Urdu, Hindi & English, together",
    "07-prayer.png":    "Prayer times, fully on-device",
    "08-reminders.png": "Gentle Sunnah reminders",
    "10-audio.png":     "Listen — verse-by-verse recitation",
    "11-about.png":     "Offline, private — no sign-up",
    "12-fontzoom.png":  "Pinch to zoom — read at any size",
    # New phone "one continuous session" story — all Al-Baqarah, Fajr light
    # (#EAEEF1), same anchor verse 2:2, reading font 32 (matches slot 2), ending
    # on pinch-to-zoom. Fresh 13–18 filenames so the tablet set (which shares
    # 04/10/12) is left untouched. (Audio dropped — the peek already shows it.)
    "13-peek.png":      "Tap a verse — Urdu translation & audio",
    "14-detailed.png":  "Urdu, Hindi & English, together",
    "16-light.png":     "Light of Day — a light for every hour",
    "17-size.png":      "Your script, size & language",
    "18-zoom.png":      "Pinch to zoom — read at any size",
    # Smart search — find any surah by name/number, or jump straight to a verse
    # reference ("muhammad 10" → Surah Muhammad, ayah 10).
    "19-search.png":    "Find a surah — or jump to a verse",
}

# PHONE slot (up to 8) — the Al-Baqarah / Fajr story, now opening with search
# (slot 2) so the smart find/verse-jump leads, ending on pinch-to-zoom.
PHONE = ["01-home.png", "19-search.png", "02-reading.png", "13-peek.png",
         "14-detailed.png", "16-light.png", "17-size.png", "18-zoom.png"]

# TABLET (7-inch) slot — phone captures reframed to portrait; a breadth set of
# extras. The 10-inch slot uses ACTUAL tablet captures instead — see
# make_tablet_shots.py (screenshots/tablet-10in/).
TABLET = ["01-home.png", "19-search.png", "02-reading.png", "04-detailed.png",
          "10-audio.png", "08-reminders.png", "11-about.png", "07-prayer.png"]


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


def build(slot, names):
    out = os.path.join(BASE, slot)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    for pos, raw in enumerate(names, 1):
        stem = raw.split("-", 1)[1].replace(".png", "")
        frame(os.path.join(RAW, raw), CAPTIONS[raw]).save(
            os.path.join(out, f"{pos}-{stem}.png"))
        print(f"  {slot}/{pos}-{stem}.png  -  {CAPTIONS[raw]}")


if __name__ == "__main__":
    print("PHONE slot (upload to Phone screenshots):")
    build("phone", PHONE)
    print("TABLET slot (upload to 7-inch; 10-inch uses make_tablet_shots.py):")
    build("tablet", TABLET)
