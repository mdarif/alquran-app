import '../../../../core/database/app_database.dart';
import '../../../../core/feature_flags.dart';
import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class AyahRepositoryImpl implements AyahRepository {
  const AyahRepositoryImpl(this._db, this._settings);

  final AppDatabase _db;
  final ReaderSettingsRepository _settings;

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

    // IndoPak column only when the feature is ON and the reader chose it; the
    // `?? uthmani` fallback guarantees non-null text even if the column is
    // unexpectedly empty. Flag off => always Uthmani (current behaviour).
    final indopak = FeatureFlags.indopakScript &&
        _settings.script == ArabicScript.indopak;

    return [
      for (final r in rows)
        Ayah(
          id: r.id,
          surahId: r.surahId,
          ayahNumber: r.ayahNumber,
          textArabic: indopak
              ? (r.textArabicIndopak ?? r.textArabicUthmani)
              : r.textArabicUthmani,
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
          nameArabic: s.nameArabic,
          revelationPlace: s.revelationPlace,
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
          author: r.author,
        ),
    ];
  }
}
