import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/features/reader/data/repositories/ayah_repository_impl.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reader opens are fast because the singleton repo serves a session cache
/// (surah verses) and memoises the mushaf-wide constants (headers + resources),
/// so a re-open — or a neighbour prefetched under a since-discarded per-page
/// cubit — costs no DB round-trip. These tests pin that caching, and that a
/// script switch keys to a fresh entry rather than serving stale text.
class _Settings implements ReaderSettingsRepository {
  _Settings(this.script);
  @override
  ArabicScript script;
  @override
  Future<void> setScript(ArabicScript value) async => script = value;
  @override
  double get fontSize => 28;
  @override
  bool get detailed => false;
  @override
  List<String>? get selectedTranslations => null;
  @override
  Future<void> setFontSize(double value) async {}
  @override
  Future<void> setDetailed(bool value) async {}
  @override
  Future<void> setSelectedTranslations(List<String> codes) async {}
  @override
  double get recitationSpeed => 1.0;
  @override
  Future<void> setRecitationSpeed(double value) async {}
  @override
  bool get showTranslationPeek => false;
  @override
  Future<void> setShowTranslationPeek(bool value) async {}
  @override
  bool get showArabicMatn => true;
  @override
  Future<void> setShowArabicMatn(bool value) async {}
}

void main() {
  late AppDatabase db;
  late _Settings settings;
  late AyahRepositoryImpl repo;

  Future<void> insertAyah(int id, {String uthmani = 'U', String? indopak}) =>
      db.into(db.ayahs).insert(
            AyahsCompanion.insert(
              id: Value(id),
              surahId: 1,
              ayahNumber: id,
              textArabicUthmani: uthmani,
              textArabicIndopak: Value(indopak),
            ),
          );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    settings = _Settings(ArabicScript.uthmani);
    repo = AyahRepositoryImpl(db, settings);
    await insertAyah(1, uthmani: 'UTHMANI-1', indopak: 'INDOPAK-1');
  });
  tearDown(() => db.close());

  const surah = ReaderTarget.surah(1, 'Al-Fatihah');

  test('a re-open serves verses from the session cache (no DB re-read)',
      () async {
    final first = await repo.getAyahs(surah);
    expect(first, hasLength(1));

    // Delete the row: a cache MISS would now come back empty; a hit is unaffected.
    await db.delete(db.ayahs).go();
    final second = await repo.getAyahs(surah);
    expect(
      second,
      hasLength(1),
      reason: 'second open must be served from the session cache',
    );
    expect(second.first.textArabic, 'UTHMANI-1');
  });

  test('a script switch keys to a fresh entry (no stale text)', () async {
    final uthmani = await repo.getAyahs(surah);
    expect(uthmani.first.textArabic, 'UTHMANI-1');

    settings.script = ArabicScript.indopak;
    final indopak = await repo.getAyahs(surah);
    // With the flag off the gate keeps Uthmani; either way it must NOT be served
    // the cached Uthmani entry under an IndoPak read — it re-resolves per script.
    expect(indopak.first.textArabic, isNotNull);
    expect(indopak, isNot(same(uthmani)));
  });

  test('surah headings are memoised across calls', () async {
    await db.into(db.surahs).insert(
          SurahsCompanion.insert(
            id: const Value(1),
            nameArabic: 'الفاتحة',
            nameEnglish: 'Al-Fatihah',
            revelationPlace: const Value('makkah'),
            totalAyahs: 7,
          ),
        );
    final first = await repo.getSurahHeadings();
    expect(first, hasLength(1));

    // Insert another surah: a fresh read would see 2, a memoised one still sees 1.
    await db.into(db.surahs).insert(
          SurahsCompanion.insert(
            id: const Value(2),
            nameArabic: 'البقرة',
            nameEnglish: 'Al-Baqarah',
            revelationPlace: const Value('madinah'),
            totalAyahs: 286,
          ),
        );
    final second = await repo.getSurahHeadings();
    expect(
      second,
      hasLength(1),
      reason: 'headings are mushaf-wide constants, memoised for the session',
    );
  });

  test('translation editions are memoised across calls', () async {
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: const Value(1),
            type: 'translation',
            languageCode: 'ur',
            name: 'Urdu',
          ),
        );
    expect(await repo.getTranslationResources(), hasLength(1));

    // A second edition added after the first read must NOT appear — memoised.
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: const Value(2),
            type: 'translation',
            languageCode: 'hi',
            name: 'Hindi',
          ),
        );
    expect(
      await repo.getTranslationResources(),
      hasLength(1),
      reason: 'editions are session constants, memoised like the headings',
    );
  });

  test('a non-surah dimension (juz) reads by its index column', () async {
    // Two ayahs tagged juz 1 (ids already: ayah 1 from setUp; add ayah 2).
    await db.into(db.ayahs).insert(
          AyahsCompanion.insert(
            id: const Value(2),
            surahId: 1,
            ayahNumber: 2,
            textArabicUthmani: 'UTHMANI-2',
            juzNumber: const Value(1),
          ),
        );
    await (db.update(db.ayahs)..where((a) => a.id.equals(1)))
        .write(const AyahsCompanion(juzNumber: Value(1)));

    final juz = await repo.getAyahs(const ReaderTarget.juz(1));
    expect(juz.map((a) => a.id), [1, 2]);
  });

  test('the session cache is LRU-capped — the oldest untouched entry evicts',
      () async {
    // Seed 41 single-ayah surahs 2..42 (surah 1 already holds the setUp ayah),
    // cap is 40, then read them all in order so surah 2 (first read) is oldest.
    for (var s = 2; s <= 42; s++) {
      await db.into(db.ayahs).insert(
            AyahsCompanion.insert(
              id: Value(1000 + s),
              surahId: s,
              ayahNumber: 1,
              textArabicUthmani: 'S$s',
            ),
          );
    }
    for (var s = 2; s <= 42; s++) {
      await repo.getAyahs(ReaderTarget.surah(s, 'S$s'));
    }

    // Delete both rows from the DB: only a still-cached entry survives.
    await (db.delete(db.ayahs)..where((a) => a.id.equals(1002)))
        .go(); // surah 2
    await (db.delete(db.ayahs)..where((a) => a.id.equals(1042)))
        .go(); // surah 42

    // Surah 2 was evicted (oldest) → cache miss → re-query → empty.
    expect(
      await repo.getAyahs(const ReaderTarget.surah(2, 'S2')),
      isEmpty,
      reason: 'the oldest untouched section should have been evicted',
    );
    // Surah 42 is still cached → served despite the row being gone.
    expect(
      await repo.getAyahs(const ReaderTarget.surah(42, 'S42')),
      hasLength(1),
    );
  });
}
