import 'package:drift/drift.dart';

// Drift table definitions mirroring pipeline/schema.sql in the alquran-data repo.
// Column names map to the DB's snake_case via case_from_dart_to_sql (build.yaml),
// so `nameArabic` -> `name_arabic`, `surahId` -> `surah_id`, etc.

@DataClassName('SurahRow')
class Surahs extends Table {
  IntColumn get id => integer()(); // 1..114
  TextColumn get nameArabic => text()();
  TextColumn get nameEnglish => text()(); // transliteration, e.g. "Al-Fatihah"
  TextColumn get revelationPlace => text().nullable()(); // makkah | madinah
  IntColumn get totalAyahs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AyahRow')
class Ayahs extends Table {
  IntColumn get id => integer()(); // global running id 1..6236
  IntColumn get surahId => integer()();
  IntColumn get ayahNumber => integer()();
  TextColumn get textArabicUthmani => text()();
  TextColumn get textArabicIndopak => text().nullable()(); // Phase 2
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get juzNumber => integer().nullable()();
  IntColumn get hizbNumber => integer().nullable()();
  IntColumn get rubElHizb => integer().nullable()();
  IntColumn get rukuNumber => integer().nullable()();
  IntColumn get sajda => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ResourceRow')
class Resources extends Table {
  IntColumn get id => integer()();
  TextColumn get type => text()(); // translation | tafsir | transliteration
  TextColumn get languageCode => text()(); // ur | hi
  TextColumn get name => text()();
  TextColumn get author => text().nullable()();
  TextColumn get license => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TranslationRow')
class Translations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ayahId => integer()();
  IntColumn get resourceId => integer()();
  TextColumn get textContent => text()();
}

@DataClassName('DbMetaRow')
class DbMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
