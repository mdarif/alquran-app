#!/usr/bin/env python3
"""Derive the launcher adaptive-icon layers + splash logo from the master art.

The owner-approved launcher master is the calligraphic gold "Q" on a flat deep
green field at ``assets/icon/icon.png`` (used as-is for iOS + legacy Android).
Android's *adaptive* icon and the splash screen need the mark on transparent, so
this script regenerates those from the master so every surface shows the same Q:

  icon.png  ──►  icon_foreground.png  (gold Q on transparent, scaled into the
                                       adaptive safe zone — Android adaptive icon)
            ├─►  icon_background.png  (the flat green field, sampled from icon.png)
            └─►  splash_logo.png      (gold Q on transparent, smaller/more padded
                                       so it reads modestly full-screen — splash)

The master is flat gold-on-flat-green, so the Q separates cleanly by keying on the
red channel (green field R≈8, gold mark R≈216 — strongly bimodal), which yields
soft anti-aliased edges with no green halo. No SVG renderer required.

Run after replacing assets/icon/icon.png, then regenerate the per-platform assets:
    python3 tools/icon/derive_adaptive.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ICON_DIR = Path(__file__).resolve().parents[2] / "assets" / "icon"
MASTER = ICON_DIR / "icon.png"
FOREGROUND = ICON_DIR / "icon_foreground.png"
BACKGROUND = ICON_DIR / "icon_background.png"
SPLASH = ICON_DIR / "splash_logo.png"

OUT_SIZE = 1024          # flutter_launcher_icons / native-splash source resolution
# Fraction of the canvas the mark's longest side fills in the foreground. Note
# flutter_launcher_icons wraps the foreground in a 16% <inset>, so the mark's
# final on-icon size is MARK_FRAC * 0.68 (≈0.50 here). That keeps the Q (incl.
# the rising tail) inside Android's strict ~66% adaptive safe zone with margin so
# launcher masks (circle/squircle) never clip it, while still reading
# confidently. Tune + verify on device.
MARK_FRAC = 0.74
# Splash logo: the Q on transparent, deliberately smaller/more padded than the
# icon so flutter_native_splash places it at a tasteful ~30% of screen width
# (the whole 1024 canvas maps to the centred logo region, so a 0.46 mark reads
# modestly rather than dominating the screen).
SPLASH_FRAC = 0.46
# Red-channel alpha ramp: at/below LO → transparent (green field), at/above HI →
# opaque (gold mark); between → the anti-aliased edge, ramped for a clean cut.
KEY_LO, KEY_HI = 64, 160


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")

    # Flat background green, sampled as the median of the four corners.
    w, h = master.size
    corners = [master.getpixel(p) for p in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]
    green = tuple(sorted(c[i] for c in corners)[len(corners) // 2] for i in range(3))

    # Alpha mask from the red channel → crisp gold/green separation.
    span = KEY_HI - KEY_LO
    alpha = master.getchannel("R").point(
        lambda r: 0 if r <= KEY_LO else 255 if r >= KEY_HI else round((r - KEY_LO) / span * 255)
    )

    # The Q on transparent = the master's colours carried by that alpha, cropped.
    qmark = master.copy()
    qmark.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("No mark detected — check the red-channel key thresholds.")
    qmark = qmark.crop(bbox)

    def place(frac: float, path: Path) -> None:
        """Scale the Q so its longest side is `frac` of the canvas, centred, transparent."""
        scale = round(OUT_SIZE * frac) / max(qmark.size)
        m = qmark.resize((round(qmark.width * scale), round(qmark.height * scale)), Image.LANCZOS)
        canvas = Image.new("RGBA", (OUT_SIZE, OUT_SIZE), (0, 0, 0, 0))
        canvas.paste(m, ((OUT_SIZE - m.width) // 2, (OUT_SIZE - m.height) // 2), m)
        canvas.save(path)

    place(MARK_FRAC, FOREGROUND)
    place(SPLASH_FRAC, SPLASH)
    Image.new("RGBA", (OUT_SIZE, OUT_SIZE), (*green, 255)).save(BACKGROUND)

    pct = lambda v: f"{100 * v / w:.1f}%"
    print(f"master      {MASTER.name}  {master.size}")
    print(f"green field rgb{green}  #{green[0]:02X}{green[1]:02X}{green[2]:02X}")
    print(f"mark bbox   x {pct(bbox[0])}-{pct(bbox[2])}  y {pct(bbox[1])}-{pct(bbox[3])}")
    print(f"foreground  {FOREGROUND.name}  Q {MARK_FRAC:.0%} of {OUT_SIZE}px (adaptive icon)")
    print(f"splash      {SPLASH.name}  Q {SPLASH_FRAC:.0%} of {OUT_SIZE}px (native splash)")
    print(f"background  {BACKGROUND.name}  flat green {OUT_SIZE}px")


if __name__ == "__main__":
    main()
