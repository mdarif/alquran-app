import 'package:equatable/equatable.dart';

/// Pure domain entity for a surah (PRD 7.1: domain layer is Flutter/data-free).
class Surah extends Equatable {
  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.totalAyahs,
    this.revelationPlace,
  });

  final int id; // 1..114
  final String nameArabic;
  final String nameEnglish;
  final int totalAyahs;
  final String? revelationPlace; // makkah | madinah

  @override
  List<Object?> get props =>
      [id, nameArabic, nameEnglish, totalAyahs, revelationPlace];
}
