import '../../../../core/database/app_database.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';

class AyahRepositoryImpl implements AyahRepository {
  const AyahRepositoryImpl(this._db);

  final AppDatabase _db;

  // The QPC text carries an end-of-ayah marker (a trailing space + Arabic-Indic
  // digits U+0660–U+0669, optionally the U+06DD ornament). We render our own
  // ayah numbers, so strip the baked-in marker once on read.
  static final RegExp _endOfAyahMarker = RegExp('[\\s۝٠-٩]+\$');

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final rows = await switch (target.dimension) {
      ReaderDimension.surah => _db.ayahsForSurah(target.value),
      ReaderDimension.juz => _db.ayahsForJuz(target.value),
      ReaderDimension.hizb => _db.ayahsForHizb(target.value),
      ReaderDimension.page => _db.ayahsForPage(target.value),
      ReaderDimension.ruku => _db.ayahsForRuku(target.value),
    };

    final translations =
        await _db.translationsForAyahIds([for (final r in rows) r.id]);

    return [
      for (final r in rows)
        Ayah(
          id: r.id,
          surahId: r.surahId,
          ayahNumber: r.ayahNumber,
          textArabic: r.textArabicUthmani.replaceAll(_endOfAyahMarker, ''),
          isSajda: r.sajda == 1,
          page: r.pageNumber,
          juz: r.juzNumber,
          hizb: r.hizbNumber,
          rubElHizb: r.rubElHizb,
          ruku: r.rukuNumber,
          translations: translations[r.id] ?? const {},
        ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async {
    final rows = await _db.allSurahs();
    return {
      for (final s in rows)
        s.id: SurahHeading(
          number: s.id,
          nameEnglish: s.nameEnglish,
          totalAyahs: s.totalAyahs,
        ),
    };
  }

  @override
  Future<List<TranslationResource>> getTranslationResources() async {
    final rows = await _db.translationResources();
    return [
      for (final r in rows)
        TranslationResource(
          id: r.id,
          languageCode: r.languageCode,
          name: r.name,
        ),
    ];
  }
}
