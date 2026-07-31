import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/features/reader/data/repositories/ayah_bookmark_repository_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AyahBookmarkRepositoryImpl> _repo([List<String>? saved]) async {
  SharedPreferences.setMockInitialValues({
    if (saved != null) 'reader_ayah_bookmarks': saved,
  });
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.createMigrator().createAll();
  addTearDown(db.close);
  return AyahBookmarkRepositoryImpl(await SharedPreferences.getInstance(), db);
}

void main() {
  group('AyahBookmarkRepositoryImpl', () {
    test('starts empty', () async {
      final repo = await _repo();

      expect(repo.bookmarkedAyahIds, isEmpty);
      expect(repo.isBookmarked(255), isFalse);
    });

    test('adds and removes a bookmark by global ayah id', () async {
      final repo = await _repo();

      await repo.setBookmarked(255, true);
      expect(repo.isBookmarked(255), isTrue);
      expect(repo.bookmarkedAyahIds, {255});

      await repo.setBookmarked(255, false);
      expect(repo.isBookmarked(255), isFalse);
      expect(repo.bookmarkedAyahIds, isEmpty);
    });

    test('deduplicates and stores ids in numeric order', () async {
      final repo = await _repo(['8', '1', '8']);

      await repo.setBookmarked(255, true);

      expect(repo.bookmarkedAyahIds.toList(), [1, 8, 255]);
    });

    test('ignores corrupt stored entries', () async {
      final repo = await _repo(['8', 'oops', '-1', '0']);

      expect(repo.bookmarkedAyahIds, {8});
    });

    test('hydrates saved ayahs in mushaf order', () async {
      SharedPreferences.setMockInitialValues({
        'reader_ayah_bookmarks': ['2', '1'],
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
      addTearDown(db.close);
      await db.into(db.ayahs).insert(
            AyahsCompanion.insert(
              id: const Value(1),
              surahId: 1,
              ayahNumber: 1,
              textArabicUthmani: 'one',
            ),
          );
      await db.into(db.ayahs).insert(
            AyahsCompanion.insert(
              id: const Value(2),
              surahId: 1,
              ayahNumber: 2,
              textArabicUthmani: 'two',
            ),
          );
      final repo = AyahBookmarkRepositoryImpl(
        await SharedPreferences.getInstance(),
        db,
      );

      final ayahs = await repo.bookmarkedAyahs();

      expect([for (final ayah in ayahs) ayah.id], [1, 2]);
      expect(ayahs.last.textArabic, 'two');
    });
  });
}
