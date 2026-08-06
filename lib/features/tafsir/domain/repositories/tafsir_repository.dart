import '../entities/tafsir_catalogue_entry.dart';
import '../entities/tafsir_entry.dart';
import '../entities/tafsir_resource.dart';

class TafsirIntegrityException implements Exception {
  const TafsirIntegrityException(this.slug, this.detail);
  final String slug;
  final String detail;

  @override
  String toString() => 'TafsirIntegrityException($slug): $detail';
}

class TafsirDownloadException implements Exception {
  const TafsirDownloadException(this.detail);
  final String detail;

  @override
  String toString() => 'TafsirDownloadException: $detail';
}

abstract interface class TafsirRepository {
  Future<TafsirCatalogue> catalogue();
  Future<List<TafsirResource>> installed();
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  });
  Future<void> remove(String slug);
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  });
}
