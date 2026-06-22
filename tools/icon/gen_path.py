#!/usr/bin/env python3
"""Shape an Arabic word with HarfBuzz, emit an ImageMagick draw-path centred in
a target box. Outputs the path 'd' string on stdout."""
import sys, json
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Identity

FONT = sys.argv[1]
TEXT = sys.argv[2]
IMG = int(sys.argv[3])          # canvas size (square)
BOX = float(sys.argv[4])        # max text box (fraction of canvas) for fit

# --- shape ---
blob = hb.Blob.from_file_path(FONT)
face = hb.Face(blob)
font = hb.Font(face)
upem = face.upem
buf = hb.Buffer()
buf.add_str(TEXT)
buf.guess_segment_properties()      # -> RTL, Arabic
hb.shape(font, buf)
infos = buf.glyph_infos
poss = buf.glyph_positions

tt = TTFont(FONT)
order = tt.getGlyphOrder()
glyphSet = tt.getGlyphSet()

# layout in font units (y-up), pen advancing left->right in visual order
placed = []  # (glyphName, penX, xoff, yoff)
penX = 0
for info, pos in zip(infos, poss):
    name = order[info.codepoint]
    placed.append((name, penX + pos.x_offset, pos.y_offset))
    penX += pos.x_advance
advance_w = penX

# union bbox of the actual outlines in font units
minx = miny = 1e9
maxx = maxy = -1e9
for name, ox, oy in placed:
    bp = BoundsPen(glyphSet)
    glyphSet[name].draw(bp)
    if bp.bounds is None:
        continue
    x0, y0, x1, y1 = bp.bounds
    minx = min(minx, x0 + ox); maxx = max(maxx, x1 + ox)
    miny = min(miny, y0 + oy); maxy = max(maxy, y1 + oy)

tw_fu = maxx - minx
th_fu = maxy - miny
box_px = IMG * BOX
s = min(box_px / tw_fu, box_px / th_fu)

# centre the ink bbox in the canvas
draw_w = tw_fu * s
draw_h = th_fu * s
padX = (IMG - draw_w) / 2.0
padY = (IMG - draw_h) / 2.0
# map font-unit point (X,Y) -> pixel: px = (X-minx)*s + padX ; py = IMG - ((Y-miny)*s + padY)

parts = []
for name, ox, oy in placed:
    # affine for TransformPen: x'=xx*x+yx*y+dx ; y'=xy*x+yy*y+dy
    xx = s
    yy = -s
    dx = (ox - minx) * s + padX
    dy = IMG - (((oy - miny) * s) + padY)
    pen = SVGPathPen(glyphSet)
    tpen = TransformPen(pen, (xx, 0, 0, yy, dx, dy))
    glyphSet[name].draw(tpen)
    cmds = pen.getCommands()
    if cmds:
        parts.append(cmds)

sys.stdout.write(" ".join(parts))
sys.stderr.write(json.dumps({
    "glyphs": len(placed), "scale": round(s, 4),
    "text_w_px": round(draw_w, 1), "text_h_px": round(draw_h, 1)}) + "\n")
