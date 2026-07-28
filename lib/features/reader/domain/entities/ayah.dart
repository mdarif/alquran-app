import 'package:equatable/equatable.dart';

/// A single ayah with its Arabic text, structural indices, and any translations
/// (keyed by translation resource id).
class Ayah extends Equatable {
  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.textArabic,
    required this.isSajda,
    this.page,
    this.juz,
    this.hizb,
    this.rubElHizb,
    this.ruku,
    this.translations = const {},
  });

  final int id;
  final int surahId;
  final int ayahNumber;
  final String textArabic;
  final bool isSajda;
  final int? page;
  final int? juz;
  final int? hizb;
  final int? rubElHizb;
  final int? ruku;

  /// Edition SLUG -> translated text. Slug, not resource id: a downloaded
  /// edition has no row in `resources`, and ids shift when the data pipeline
  /// reorders its sources.
  final Map<String, String> translations;

  @override
  List<Object?> get props => [
        id,
        surahId,
        ayahNumber,
        textArabic,
        isSajda,
        page,
        juz,
        hizb,
        rubElHizb,
        ruku,
        translations,
      ];
}
