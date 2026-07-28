import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'editions_database.g.dart';

/// Downloaded translation editions, in a database of their own.
///
/// **This must never be merged into `quran.db`.** The bundled seed DB is
/// overwritten wholesale whenever its version marker changes (see
/// `db_seeder.dart`), so anything written into it is destroyed on the next app
/// update — a reader would silently lose every translation they had downloaded.
/// Keeping downloads in a separate file the seeder never touches is the whole
/// reason this class exists.
///
/// Rows are addressed by `(slug, surah, ayah)` rather than by the global ayah
/// id. An installed edition outlives the build that produced it, so it must not
/// depend on an id space that a future data refresh could renumber.
@DriftDatabase(tables: [InstalledEditions, EditionTexts])
class EditionsDatabase extends _$EditionsDatabase {
  EditionsDatabase(File file) : super(_open(file));

  EditionsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<List<InstalledEditionRow>> installed() => (select(installedEditions)
        ..orderBy([
          (e) => OrderingTerm.asc(e.sortOrder),
          (e) => OrderingTerm.asc(e.slug),
        ]))
      .get();

  Future<bool> isInstalled(String slug) async =>
      await (select(installedEditions)..where((e) => e.slug.equals(slug)))
          .getSingleOrNull() !=
      null;

  /// Texts for one surah of one edition: ayah number -> text.
  Future<Map<int, String>> textsForSurah(String slug, int surahId) async {
    final rows = await (select(editionTexts)
          ..where((t) => t.slug.equals(slug) & t.surah.equals(surahId)))
        .get();
    return {for (final r in rows) r.ayah: r.content};
  }

  /// Texts for one surah across several editions: slug -> (ayah -> text).
  Future<Map<String, Map<int, String>>> textsForSurahAll(
    List<String> slugs,
    int surahId,
  ) async {
    if (slugs.isEmpty) return const {};
    final rows = await (select(editionTexts)
          ..where((t) => t.slug.isIn(slugs) & t.surah.equals(surahId)))
        .get();
    final out = <String, Map<int, String>>{};
    for (final r in rows) {
      (out[r.slug] ??= {})[r.ayah] = r.content;
    }
    return out;
  }

  /// Replace an edition wholesale, inside one transaction.
  ///
  /// Atomic on purpose: a half-written edition would render blank verses rather
  /// than fail, which is the failure mode this whole feature has to avoid.
  Future<void> replaceEdition(
    InstalledEditionsCompanion edition,
    List<EditionTextsCompanion> texts,
  ) =>
      transaction(() async {
        final slug = edition.slug.value;
        await (delete(editionTexts)..where((t) => t.slug.equals(slug))).go();
        await (delete(installedEditions)..where((e) => e.slug.equals(slug)))
            .go();
        await into(installedEditions).insert(edition);
        await batch((b) => b.insertAll(editionTexts, texts));
      });

  Future<void> removeEdition(String slug) => transaction(() async {
        await (delete(editionTexts)..where((t) => t.slug.equals(slug))).go();
        await (delete(installedEditions)..where((e) => e.slug.equals(slug)))
            .go();
      });
}

/// One installed edition's metadata — the same fields the bundled `resources`
/// table carries, so the reader can treat both alike.
@DataClassName('InstalledEditionRow')
class InstalledEditions extends Table {
  TextColumn get slug => text()();
  TextColumn get type => text()();
  TextColumn get languageCode => text()();
  TextColumn get name => text()();
  TextColumn get nativeName => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get direction => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get license => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  IntColumn get ayahCount => integer().withDefault(const Constant(0))();

  /// Bytes on disk after expanding — what the Translations screen reports as
  /// the cost of keeping this edition.
  IntColumn get bytes => integer().withDefault(const Constant(0))();

  /// The sha256 of the artifact this was installed from, so a catalogue update
  /// can tell "already installed" from "a newer build of the same edition".
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {slug};
}

@DataClassName('EditionTextRow')
class EditionTexts extends Table {
  TextColumn get slug => text()();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();

  /// The verse text. Named `content`, not `text`: a column called `text` would
  /// shadow Drift's own `Table.text()` column builder and the table fails to
  /// generate.
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {slug, surah, ayah};
}

LazyDatabase _open(File file) =>
    LazyDatabase(() async => NativeDatabase.createInBackground(file));
