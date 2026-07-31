import '../entities/ayah.dart';

/// Stores ayah-level bookmarks by the app's stable global ayah id (1..6236).
///
/// The repository deliberately does not persist `resources.id` or translation
/// choices; a bookmark is only the verse address. Notes/tags can layer on later.
abstract interface class AyahBookmarkRepository {
  Set<int> get bookmarkedAyahIds;

  bool isBookmarked(int ayahId);

  Future<void> setBookmarked(int ayahId, bool bookmarked);

  /// Saved verses in mushaf order, hydrated enough for a bookmark list.
  Future<List<Ayah>> bookmarkedAyahs();
}
