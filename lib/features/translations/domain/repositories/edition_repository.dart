import '../entities/catalogue_entry.dart';
import '../entities/installed_edition.dart';

/// Thrown when an artifact fails its integrity check.
///
/// Deliberately its own type: this is not a transient network error to be
/// retried silently. It means the bytes we received are not the bytes the
/// catalogue describes, and installing them would put unverified text in front
/// of a reader as scripture.
class EditionIntegrityException implements Exception {
  const EditionIntegrityException(this.slug, this.detail);
  final String slug;
  final String detail;

  @override
  String toString() => 'EditionIntegrityException($slug): $detail';
}

/// Network or server failure while fetching the catalogue or an artifact.
class EditionDownloadException implements Exception {
  const EditionDownloadException(this.detail);
  final String detail;

  @override
  String toString() => 'EditionDownloadException: $detail';
}

abstract interface class EditionRepository {
  /// Editions available for download.
  ///
  /// Returns the cached copy when the network is unavailable, so the screen
  /// still lists what the reader already knows about instead of appearing
  /// empty. Throws [EditionDownloadException] only when there is no cache
  /// either.
  Future<EditionCatalogue> catalogue();

  /// Editions currently on this device (excluding the bundled ones).
  Future<List<InstalledEdition>> installed();

  /// Download, verify and install one edition.
  ///
  /// [onProgress] receives 0..1 where the total size is known. Throws
  /// [EditionIntegrityException] if either digest fails — nothing is installed
  /// in that case.
  Future<void> install(
    CatalogueEntry entry, {
    void Function(double progress)? onProgress,
  });

  /// Remove a downloaded edition and its text.
  Future<void> remove(String slug);
}
