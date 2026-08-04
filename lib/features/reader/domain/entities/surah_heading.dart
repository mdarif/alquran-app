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
    this.nameMeaning,
  });

  final int number;
  final String nameEnglish;
  final int totalAyahs;

  /// Arabic surah name (e.g. الفاتحة). Null only in synthetic test fixtures.
  final String? nameArabic;

  /// Revelation place as stored in the DB: "makkah" | "madinah" (nullable).
  final String? revelationPlace;

  /// English meaning of the surah name (e.g. "The Forgiver" for Ghafir).
  /// Static/curated, not sourced from the DB — see core/data/surah_meanings.dart.
  final String? nameMeaning;

  @override
  List<Object?> get props => [
        number,
        nameEnglish,
        totalAyahs,
        nameArabic,
        revelationPlace,
        nameMeaning,
      ];
}
