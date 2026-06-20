import '../entities/ayah.dart';
import '../entities/translation_resource.dart';

abstract interface class AyahRepository {
  /// Ayahs of a surah, each with its translations attached.
  Future<List<Ayah>> getAyahs(int surahId);

  /// Active translation editions (MVP: Urdu + Hindi), for column headers.
  Future<List<TranslationResource>> getTranslationResources();
}
