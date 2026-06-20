import 'package:equatable/equatable.dart';

/// Minimal surah metadata the reader needs to draw a chapter header when a
/// section crosses surah boundaries (juz/hizb/page/ruku). Kept inside the reader
/// feature to avoid a cross-feature import of the surahs domain.
class SurahHeading extends Equatable {
  const SurahHeading({
    required this.number,
    required this.nameEnglish,
    required this.totalAyahs,
    this.nameArabic,
    this.revelationPlace,
  });

  final int number;
  final String nameEnglish;
  final int totalAyahs;

  /// Arabic surah name (e.g. الفاتحة). Null only in synthetic test fixtures.
  final String? nameArabic;

  /// Revelation place as stored in the DB: "makkah" | "madinah" (nullable).
  final String? revelationPlace;

  @override
  List<Object?> get props =>
      [number, nameEnglish, totalAyahs, nameArabic, revelationPlace];
}
