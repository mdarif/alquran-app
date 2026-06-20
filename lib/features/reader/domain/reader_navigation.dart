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
