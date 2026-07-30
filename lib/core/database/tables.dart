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

/// A text edition — one translation or transliteration of the Qur'an.
///
/// [slug] is the STABLE identity and the only value safe to persist (in
/// SharedPreferences, in a download filename). [id] is NOT: the data pipeline
/// assigns it from `cur.lastrowid`, so every id shifts when an edition is added
/// to or reordered in its `sources.yaml`.
///
/// [languageCode] GROUPS editions; it does not identify one. Several editions
/// may share a language, so nothing may assume one row per language.
@DataClassName('ResourceRow')
class Resources extends Table {
  IntColumn get id => integer()();
  TextColumn get slug => text()(); // stable id, e.g. "ur-junagarhi"
  TextColumn get type => text()(); // translation | tafsir | transliteration
  TextColumn get languageCode => text()(); // ur | hi  (grouping only)
  TextColumn get name => text()();
  TextColumn get nativeName => text().nullable()(); // اردو, हिन्दी
  TextColumn get author => text().nullable()();
  TextColumn get direction => text().nullable()(); // rtl | ltr

  /// Global display order across all editions, not per-language: it fixes the
  /// reading order under each verse (Urdu first) and the picker's grouping.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Shown to a reader who has never chosen. At least one edition has this.
  IntColumn get defaultOn => integer().withDefault(const Constant(0))();
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

/// Manually verified local moon-sighting corrections for the Hijri date
/// display, keyed by the Gregorian date FROM WHICH the correction applies
/// (until superseded by the next anchor for the same [region]). Replaces a
/// pure tabular (Kuwaiti) calendar, which is astronomically calculated and
/// drifts from the region's actual sighting-based announcement by a variable
/// (not constant) number of days — see HijriAnchorRepository.
///
/// SQL shape (mirrors this table, for reference/pipeline use):
/// ```sql
/// CREATE TABLE hijri_anchor_points (
///   gregorian_date TEXT NOT NULL,   -- 'YYYY-MM-DD', from-date (inclusive)
///   region TEXT NOT NULL,           -- e.g. 'PK', 'IN' — sighting authority
///   correction_days INTEGER NOT NULL, -- applied to the tabular result
///   source TEXT,                    -- e.g. 'Ruet-e-Hilal Committee PK'
///   PRIMARY KEY (gregorian_date, region)
/// );
/// ```
@DataClassName('HijriAnchorPointRow')
class HijriAnchorPoints extends Table {
  TextColumn get gregorianDate => text()(); // 'YYYY-MM-DD'
  TextColumn get region => text()(); // 'PK' | 'IN' | ...
  IntColumn get correctionDays => integer()();
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {gregorianDate, region};
}
