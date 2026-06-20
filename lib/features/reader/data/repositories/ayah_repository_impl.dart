import '../../../../core/database/app_database.dart';
import '../../domain/entities/ayah.dart';
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
  Future<List<Ayah>> getAyahs(int surahId) async {
    final rows = await _db.ayahsForSurah(surahId);
    final translations = await _db.translationsForSurah(surahId);

    return rows
        .map(
          (r) => Ayah(
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
        )
        .toList();
  }

  @override
  Future<List<TranslationResource>> getTranslationResources() async {
    final rows = await _db.translationResources();
    return rows
        .map(
          (r) => TranslationResource(
            id: r.id,
            languageCode: r.languageCode,
            name: r.name,
          ),
        )
        .toList();
  }
}
