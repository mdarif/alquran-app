import '../entities/ayah.dart';
import '../entities/reader_target.dart';
import '../entities/surah_heading.dart';
import '../entities/translation_resource.dart';

abstract interface class AyahRepository {
  /// Ayahs for a navigation target (surah/juz/hizb/page/ruku), in mushaf order,
  /// each with its translations attached. May span multiple surahs.
  Future<List<Ayah>> getAyahs(ReaderTarget target);

  /// Surah metadata (number, English name, ayah count) keyed by surah id, for
  /// drawing chapter headers when a section crosses surah boundaries.
  Future<Map<int, SurahHeading>> getSurahHeadings();

  /// Active translation editions (MVP: Urdu + Hindi), for column headers.
  Future<List<TranslationResource>> getTranslationResources();
}
