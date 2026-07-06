import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/features/surahs/data/repositories/surah_repository_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the real DB-row → [Surah] mapping (the cubit tests only ever fake this
/// repo, so the mapping + id ordering had no guard).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
  });
  tearDown(() => db.close());

  Future<void> insertSurah(
    int id,
    String ar,
    String en,
    int total, {
    String? place,
  }) =>
      db.into(db.surahs).insert(
            SurahsCompanion.insert(
              id: Value(id),
              nameArabic: ar,
              nameEnglish: en,
              totalAyahs: total,
              revelationPlace: Value(place),
            ),
          );

  test('maps every column and returns surahs in id order', () async {
    // Insert out of order to prove the ordering comes from the query, not input.
    await insertSurah(2, 'البقرة', 'Al-Baqarah', 286, place: 'madinah');
    await insertSurah(1, 'الفاتحة', 'Al-Fatihah', 7, place: 'makkah');

    final surahs = await SurahRepositoryImpl(db).getSurahs();

    expect(surahs.map((s) => s.id), [1, 2]);
    final fatiha = surahs.first;
    expect(fatiha.nameArabic, 'الفاتحة');
    expect(fatiha.nameEnglish, 'Al-Fatihah');
    expect(fatiha.totalAyahs, 7);
    expect(fatiha.revelationPlace, 'makkah');
  });

  test('preserves a null revelation place', () async {
    await insertSurah(1, 'الفاتحة', 'Al-Fatihah', 7);
    final surahs = await SurahRepositoryImpl(db).getSurahs();
    expect(surahs.single.revelationPlace, isNull);
  });
}
