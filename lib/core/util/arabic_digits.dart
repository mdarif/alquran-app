/// Numeral helpers for verse/surah numbers.
///
/// Two distinct scripts, used in two distinct places — do not conflate them:
///
/// * [toArabicIndicDigits] (U+0660–U+0669) is for the **Mushaf ayah-end rosette**.
///   The KFGQPC font composes *these* code points (and only these) into the ornate
///   medallion glyph via GSUB. Swap in Persian/Urdu digits and the rosette GSUB
///   won't fire — you'd get a bare digit instead of the medallion.
/// * [toUrduDigits] (U+06F0–U+06F9, "Extended Arabic-Indic") is for the **plain UI
///   number badges** (the Detailed-view ayah badge and the chapter-header
///   medallion), rendered in the system font. Urdu/Hindi readers read ۲ as "2";
///   the Arabic-Indic ٢ looks like a "4" to them, hence we use the Eastern forms
///   in chrome while the sacred rosette keeps the canonical Mushaf glyphs.
library;

/// Canonical Arabic-Indic digits (U+0660+) — for the Mushaf rosette only.
String toArabicIndicDigits(int n) => _map(n, 0x0660);

/// Eastern Arabic-Indic (Persian/Urdu) digits (U+06F0+) — for UI number badges.
String toUrduDigits(int n) => _map(n, 0x06F0);

String _map(int n, int base) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(base + (d.codeUnitAt(0) - 0x30)))
    .join();
