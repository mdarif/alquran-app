final RegExp _endOfAyahMarker = RegExp('[\\s۝٠-٩]+\$');

// Superscript alef (U+0670) + maddah (U+0653): the obligatory-madd mark our
// source stores without a baseline carrier, and the tatweel (U+0640, kashida)
// that the QPC Uthmani edition (quran.com) puts before it to elongate the stroke.
const String _superscriptAlefMaddah = 'ٰٓ';
const String _tatweelMaddah = 'ـٰٓ';

/// Prepares stored QPC Uthmani text for display:
///
/// 1. Inserts the elongation tatweel our source omits before a superscript-alef
///    + maddah (e.g. يَٰٓأَيُّهَا → يَـٰٓأَيُّهَا). Superscript alef is a zero-width
///    mark, so without the tatweel the font draws a detached mark instead of the
///    elongated madd; with it, the font shapes the proper kashida stroke.
///    Waw/ya madds already have a baseline letter, so they're left untouched.
/// 2. Strips the baked-in end-of-ayah number marker (we render our own numbers).
String displayUthmani(String raw) => raw
    .replaceAll(_superscriptAlefMaddah, _tatweelMaddah)
    .replaceAll(_endOfAyahMarker, '');
