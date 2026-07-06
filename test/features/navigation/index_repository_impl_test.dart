import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/features/navigation/data/repositories/index_repository_impl.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the real index-start → [IndexEntry] mapping (juz/hizb/page/ruku): the
/// first ayah of each index value, labelled with its surah, in index order.
/// The cubit/view tests only fake this repo, so the DB mapping had no guard.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    // Two named surahs; a third index value starts in an unnamed surah so the
    // "Surah N" fallback is exercised.
    await db.into(db.surahs).insert(
          SurahsCompanion.insert(
            id: const Value(1),
            nameArabic: 'الفاتحة',
            nameEnglish: 'Al-Fatihah',
            totalAyahs: 7,
          ),
        );
    await db.into(db.surahs).insert(
          SurahsCompanion.insert(
            id: const Value(2),
            nameArabic: 'البقرة',
            nameEnglish: 'Al-Baqarah',
            totalAyahs: 286,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> insertAyah(int id, int surahId, int ayahNumber, int juz) =>
      db.into(db.ayahs).insert(
            AyahsCompanion.insert(
              id: Value(id),
              surahId: surahId,
              ayahNumber: ayahNumber,
              textArabicUthmani: 'x',
              juzNumber: Value(juz),
            ),
          );

  test('juz entries start at the first ayah of each juz, in order', () async {
    await insertAyah(1, 1, 1, 1); // juz 1 begins here (lowest id)
    await insertAyah(8, 2, 1, 1); // same juz, later id — NOT the start
    await insertAyah(150, 2, 143, 2); // juz 2 begins here
    await insertAyah(400, 99, 5, 3); // juz 3, surah 99 has no name row

    final entries = await IndexRepositoryImpl(db).entries(IndexKind.juz);

    expect(entries.map((e) => e.number), [1, 2, 3]);

    expect(entries[0].startSurahId, 1);
    expect(entries[0].startSurahName, 'Al-Fatihah');
    expect(entries[0].startAyah, 1);

    expect(entries[1].startSurahId, 2);
    expect(entries[1].startSurahName, 'Al-Baqarah');
    expect(entries[1].startAyah, 143);

    // Unnamed surah → graceful "Surah N" fallback, never a crash.
    expect(entries[2].startSurahName, 'Surah 99');
  });
}
