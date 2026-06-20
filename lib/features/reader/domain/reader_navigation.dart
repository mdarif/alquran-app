import 'entities/ayah.dart';
import 'entities/reader_target.dart';
import 'entities/surah_heading.dart';

/// Total number of entries in each navigation dimension. The QPC indices are
/// global and monotonic, so these are fixed mushaf-wide counts.
extension ReaderDimensionRange on ReaderDimension {
  int get count => switch (this) {
        ReaderDimension.surah => 114,
        ReaderDimension.juz => 30,
        ReaderDimension.hizb => 60,
        ReaderDimension.page => 604,
        ReaderDimension.ruku => 558,
      };
}

/// The target [delta] steps from [current] within the same dimension (e.g. +1
/// for next, -1 for previous), or `null` at the bounds — there is no wrap-around
/// (you cannot go before the first or past the last section).
///
/// Surah targets are titled with the English name from [headings] when known,
/// falling back to "Surah N"; the other dimensions title themselves.
ReaderTarget? adjacentTarget(
  ReaderTarget current,
  int delta,
  Map<int, SurahHeading> headings,
) {
  final value = current.value + delta;
  if (value < 1 || value > current.dimension.count) return null;
  return switch (current.dimension) {
    ReaderDimension.surah => ReaderTarget.surah(
        value,
        headings[value]?.nameEnglish ?? 'Surah $value',
      ),
    ReaderDimension.juz => ReaderTarget.juz(value),
    ReaderDimension.hizb => ReaderTarget.hizb(value),
    ReaderDimension.page => ReaderTarget.page(value),
    ReaderDimension.ruku => ReaderTarget.ruku(value),
  };
}

/// Estimates the printed-Mushaf page for a vertical scroll [fraction] (0..1)
/// through a flowed section. The flow is one uniform font, so vertical position
/// tracks character count well enough for a subtle "current page" readout —
/// it's an estimate, not a page-faithful boundary. Returns null if unknown.
int? pageAtFraction(List<Ayah> ayahs, double fraction) {
  if (ayahs.isEmpty) return null;
  final lengths = [for (final a in ayahs) a.textArabic.length];
  final total = lengths.fold<int>(0, (sum, l) => sum + l);
  if (total == 0) return ayahs.first.page;

  final target = fraction.clamp(0.0, 1.0) * total;
  var acc = 0;
  for (var i = 0; i < ayahs.length; i++) {
    acc += lengths[i];
    if (acc >= target) return ayahs[i].page;
  }
  return ayahs.last.page;
}
