import 'package:equatable/equatable.dart';

/// Minimal surah metadata the reader needs to draw a chapter header when a
/// section crosses surah boundaries (juz/hizb/page/ruku). Kept inside the reader
/// feature to avoid a cross-feature import of the surahs domain.
class SurahHeading extends Equatable {
  const SurahHeading({
    required this.number,
    required this.nameEnglish,
    required this.totalAyahs,
  });

  final int number;
  final String nameEnglish;
  final int totalAyahs;

  @override
  List<Object?> get props => [number, nameEnglish, totalAyahs];
}
