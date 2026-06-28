# Al Quran brand kit

The master mark is an editable SVG, not a flattened image. The
`approved-q-mark` path is traced directly from the approved PNG so its
proportions do not drift; the background remains a separate layer.

## Files

- `al-quran-mark.svg` — production-friendly master vector.
- `brand-tokens.json` — canonical colors and geometry values.
- `studio.html` — interactive editor and SVG/PNG exporter; open it directly in
  a browser.

## Guardrails

- Preserve generous clear space around the mark.
- Test variants at 24 px before approving them.
- Prefer the gold mark on deep green for primary brand moments.
- Use a one-color version when printing, embossing, or working at tiny sizes.
- Do not add Quranic text or the word Allah to launcher icons.

The studio exposes mark visibility, opacity, position, scale, rotation,
gradients, and background controls. The SVG path itself can be edited by node
in Figma, Illustrator, Sketch, or Inkscape. Its Reset button restores the
canonical values in `brand-tokens.json`.
