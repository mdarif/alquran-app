import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/repositories/ayah_bookmark_repository.dart';

class AyahBookmarkRepositoryImpl implements AyahBookmarkRepository {
  const AyahBookmarkRepositoryImpl(this._prefs, this._db);

  final SharedPreferences _prefs;
  final AppDatabase _db;

  static const String _kBookmarks = 'reader_ayah_bookmarks';

  @override
  Set<int> get bookmarkedAyahIds {
    final ids = <int>{};
    for (final raw in _prefs.getStringList(_kBookmarks) ?? const <String>[]) {
      final id = int.tryParse(raw);
      if (id != null && id > 0) ids.add(id);
    }
    return ids;
  }

  @override
  bool isBookmarked(int ayahId) => bookmarkedAyahIds.contains(ayahId);

  @override
  Future<void> setBookmarked(int ayahId, bool bookmarked) async {
    if (ayahId <= 0) return;
    final ids = bookmarkedAyahIds;
    if (bookmarked) {
      ids.add(ayahId);
    } else {
      ids.remove(ayahId);
    }
    final sorted = ids.toList()..sort();
    await _prefs.setStringList(
      _kBookmarks,
      [for (final id in sorted) '$id'],
    );
  }

  @override
  Future<List<Ayah>> bookmarkedAyahs() async {
    final rows = await _db.ayahsByIds(bookmarkedAyahIds.toList());
    final translations =
        await _db.translationsForAyahIds([for (final row in rows) row.id]);
    return [
      for (final row in rows)
        Ayah(
          id: row.id,
          surahId: row.surahId,
          ayahNumber: row.ayahNumber,
          textArabic: row.textArabicUthmani,
          isSajda: row.sajda == 1,
          page: row.pageNumber,
          juz: row.juzNumber,
          hizb: row.hizbNumber,
          rubElHizb: row.rubElHizb,
          ruku: row.rukuNumber,
          translations: translations[row.id] ?? const {},
        ),
    ];
  }
}
