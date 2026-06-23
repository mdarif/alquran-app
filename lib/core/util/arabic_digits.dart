/// Eastern Arabic-Indic ("Urdu/Persian") digits, U+06F0–U+06F9.
///
/// Used for the **Reading-view verse marker**: Urdu/Hindi readers read ۲ as "2",
/// whereas the canonical Arabic-Indic ٢ (U+0662) reads like a "4" to them. The
/// glyph must be drawn in a font that actually has these code points — the
/// KFGQPC Quran face maps U+06F0+ to placeholder dotted-circles, so the marker
/// is rendered in [AppTheme.urduFontFamily] (Noto Nastaliq Urdu), not the Quran
/// face. (Plain Western digits remain inline `'$n'` in the UI chrome badges.)
String toUrduDigits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x06F0 + (d.codeUnitAt(0) - 0x30)))
    .join();
