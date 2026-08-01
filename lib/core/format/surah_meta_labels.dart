/// How a surah describes itself in prose — shared by the TOC row and the
/// reader's surah header so the same chapter never reads two different ways.
/// Lives in `core/` because both the `surahs` and `reader` features need it and
/// features must not import each other.
library;

/// The DB's `revelation_place` ("makkah"/"madinah") as the terms readers of the
/// Qur'an actually use: **Makki** / **Madani** — when it was revealed, not
/// merely a city. Null when the DB has no (or an unrecognised) value, so the
/// caller can drop the segment rather than print a placeholder.
String? revelationLabel(String? place) {
  switch (place?.toLowerCase()) {
    case 'makkah':
    case 'mecca':
      return 'Makki';
    case 'madinah':
    case 'medina':
      return 'Madani';
    default:
      return null;
  }
}

/// "7 Ayah" — the surah's length. "Ayah" is left uninflected (rather than the
/// Arabic plural "Ayat" or an English "Verses"), matching how the count reads
/// throughout the app. Null for a non-positive count.
String? ayahCountLabel(int totalAyahs) =>
    totalAyahs > 0 ? '$totalAyahs Ayah' : null;
