#!/usr/bin/env python3
"""Bundle a correct, tiny subset of Material Symbols Rounded for the app's icons.

WHY THIS EXISTS
---------------
Material Symbols is a 4-axis variable font (FILL/wght/GRAD/opsz). Flutter's
release icon tree-shaking subsets it but **corrupts the variation (`gvar`)
table**, so in release any icon drawn at a non-default axis — every `filled`
icon and any icon not at the 24px default optical size — renders BLANK. (Debug
ships the full, intact font, so it only breaks in release.)

The fix: ship our own *correct* subset (fontTools preserves the variable axes)
containing only the icons we use (~115 KB vs the 14 MB full font / 32 MB for all
three families), reference it as a bundled app font, and build release with
`--no-tree-shake-icons` so Flutter never touches it again.

WHAT IT DOES
------------
1. Collects the Material Symbol names the app uses — from `Symbols.<name>` on
   first run, or from the `// <name>` trailing comments once converted.
2. Subsets `material_symbols_icons`'s MaterialSymbolsRounded.ttf to those glyphs,
   keeping the variable axes → assets/fonts/MaterialSymbolsRounded.ttf.
3. On first run, rewrites lib/core/theme/app_icons.dart to drop the package
   import and reference the bundled font via `IconData(0x.., fontFamily: …)`,
   keeping each glyph's name as a `// <name>` comment so this tool can re-run.

`material_symbols_icons` is a **dev_dependency** (build-time only — its fonts are
never bundled). Run after adding/removing an icon:
    python3 tools/icon/subset_symbols.py
Requires fontTools (dev) and the material_symbols_icons package in pub-cache.
"""
from __future__ import annotations

import glob
import os
import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
APP_ICONS = ROOT / "lib" / "core" / "theme" / "app_icons.dart"
OUT_FONT = ROOT / "assets" / "fonts" / "MaterialSymbolsRounded.ttf"
FAMILY = "MaterialSymbolsRounded"
FAMILY_CONST = "_kSymbolFamily"


def find_package() -> Path:
    pats = glob.glob(os.path.expanduser(
        "~/.pub-cache/hosted/*/material_symbols_icons-*"))
    if not pats:
        sys.exit("material_symbols_icons not found in pub-cache — run `flutter pub get`.")
    return Path(sorted(pats)[-1])


def name_to_codepoint(pkg: Path) -> dict[str, int]:
    src = (pkg / "lib" / "symbols.dart").read_text(errors="ignore")
    return {n: int(h, 16)
            for n, h in re.findall(r"\b([a-z0-9_]+)\s*=\s*IconData\(\s*0x([0-9a-fA-F]+)", src)}


def collect_codepoints(text: str, cp: dict[str, int]) -> list[int]:
    """Glyphs the app uses: resolved from `Symbols.x` pre-conversion, or read
    straight off the `IconData(0x..)` codepoints once converted."""
    names = set(re.findall(r"Symbols\.([a-z0-9_]+)", text)) - {"name", "name_rounded"}
    if names:
        missing = [n for n in names if n not in cp]
        if missing:
            sys.exit(f"Codepoints not resolved for: {missing}")
        return sorted({cp[n] for n in names})
    found = re.findall(rf"IconData\(\s*0x([0-9a-fA-F]+),\s*fontFamily:\s*{FAMILY_CONST}", text)
    return sorted({int(h, 16) for h in found})


def convert_app_icons(text: str, cp: dict[str, int]) -> str:
    """Drop the package import, add the family const, and turn each
    `= Symbols.x` into `= IconData(0x.., fontFamily: _kSymbolFamily) // x`."""
    text = re.sub(r"^import 'package:material_symbols_icons/symbols\.dart';\n",
                  "", text, flags=re.M)

    # Declare the family const FIRST (before the replacement injects its name).
    if f"const String {FAMILY_CONST}" not in text:
        const_line = (
            f"\n/// Bundled Material Symbols Rounded subset (see "
            f"tools/icon/subset_symbols.py — a correct, tiny replacement for the\n"
            f"/// package font, which Flutter's release tree-shaking corrupts).\n"
            f"const String {FAMILY_CONST} = '{FAMILY}';\n")
        text = re.sub(r"(import 'package:flutter/widgets\.dart';\n)",
                      r"\1" + const_line, text, count=1)

    def repl(m):
        name = m.group(1)
        # Trailing comma inside IconData(...) → `dart format` keeps it multi-line,
        # satisfying the repo's require_trailing_commas lint.
        return (f"= IconData(0x{cp[name]:04x}, fontFamily: {FAMILY_CONST},){m.group(2)}"
                f" // {name}")
    # `= Symbols.<name>;`  or  `= Symbols.<name>,`
    text = re.sub(r"= Symbols\.([a-z0-9_]+)\s*([;,])", repl, text)
    return text


def main() -> None:
    pkg = find_package()
    text = APP_ICONS.read_text()
    cp = name_to_codepoint(pkg)
    codepoints = collect_codepoints(text, cp)
    if not codepoints:
        sys.exit("No icons found in app_icons.dart.")
    print(f"distinct icon glyphs: {len(codepoints)}")

    src_font = pkg / "lib" / "fonts" / "MaterialSymbolsRounded.ttf"
    ss = subset.Subsetter(options=subset.Options(layout_features="*", name_IDs="*"))
    font = TTFont(src_font)
    ss.populate(unicodes=codepoints)
    ss.subset(font)
    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT_FONT)
    print(f"wrote {OUT_FONT.relative_to(ROOT)}  ({OUT_FONT.stat().st_size/1024:.0f} KB, "
          f"variable axes preserved)")

    if "Symbols." in text:
        new = convert_app_icons(text, cp)
        APP_ICONS.write_text(new)
        print(f"converted {APP_ICONS.relative_to(ROOT)} to the bundled font "
              f"(removed the package import)")
    else:
        print("app_icons.dart already converted — font refreshed only")


if __name__ == "__main__":
    main()
