import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The bundled, fully-offline seed database (compiled by the alquran-data
/// pipeline and shipped as an asset). The writable copy is created/refreshed by
/// `ensureSeedDatabase` (see db_seeder.dart) and passed in here; the tables
/// already exist and are populated, so the Drift migration is a no-op.
@DriftDatabase(
  tables: [Surahs, Ayahs, Resources, Translations, DbMeta, HijriAnchorPoints],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(File file) : super(_openFile(file));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // The asset DB ships with every table and all data already created by
        // the data pipeline — there is nothing to create here.
        onCreate: (m) async {},
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // --- Read queries (kept thin; feature DAOs/repositories build on these) ---

  Future<List<SurahRow>> allSurahs() =>
      (select(surahs)..orderBy([(s) => OrderingTerm.asc(s.id)])).get();

  Future<List<AyahRow>> ayahsForSurah(int surahId) => (select(ayahs)
        ..where((a) => a.surahId.equals(surahId))
        ..orderBy([(a) => OrderingTerm.asc(a.ayahNumber)]))
      .get();

  Future<List<AyahRow>> ayahsByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(ayahs)
          ..where((a) => a.id.isIn(ids))
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
  }

  /// Ayahs of an index range (juz/hizb/page/ruku), in mushaf order. These
  /// indices are global and monotonic, so ordering by the running [Ayahs.id]
  /// yields the correct reading sequence even across surah boundaries.
  Future<List<AyahRow>> ayahsForJuz(int n) =>
      _ayahsByGlobalIndex(ayahs.juzNumber, n);
  Future<List<AyahRow>> ayahsForHizb(int n) =>
      _ayahsByGlobalIndex(ayahs.hizbNumber, n);
  Future<List<AyahRow>> ayahsForPage(int n) =>
      _ayahsByGlobalIndex(ayahs.pageNumber, n);
  Future<List<AyahRow>> ayahsForRuku(int n) =>
      _ayahsByGlobalIndex(ayahs.rukuNumber, n);

  Future<List<AyahRow>> _ayahsByGlobalIndex(GeneratedColumn<int> col, int n) =>
      (select(ayahs)
            ..where((a) => col.equals(n))
            ..orderBy([(a) => OrderingTerm.asc(a.id)]))
          .get();

  /// Translations for an arbitrary set of ayahs, keyed by ayahId -> (edition
  /// SLUG -> text). Used when a reader section spans surahs (juz/hizb/page/ruku).
  ///
  /// Keyed by slug rather than resource id so bundled and downloaded editions
  /// can share one map: a downloaded edition has no row in `resources` and so no
  /// meaningful id, and ids shift upstream anyway.
  Future<Map<int, Map<String, String>>> translationsForAyahIds(
    List<int> ayahIds,
  ) async {
    if (ayahIds.isEmpty) return {};
    final query = select(translations).join([
      innerJoin(resources, resources.id.equalsExp(translations.resourceId)),
    ])
      ..where(translations.ayahId.isIn(ayahIds));
    final rows = await query.get();
    final out = <int, Map<String, String>>{};
    for (final row in rows) {
      final t = row.readTable(translations);
      final r = row.readTable(resources);
      out.putIfAbsent(t.ayahId, () => {})[r.slug] = t.textContent;
    }
    return out;
  }

  /// For an index dimension (`juz_number`, `hizb_number`, `page_number`,
  /// `ruku_number`), the first ayah of each value — used to label navigation
  /// entries with where they begin. [column] is a fixed, code-supplied name.
  Future<List<IndexStart>> indexStarts(String column) async {
    final rows = await customSelect(
      'SELECT a.$column AS idx, a.surah_id AS surah_id, a.ayah_number AS ayah '
      'FROM ayahs a '
      'WHERE a.id = (SELECT MIN(b.id) FROM ayahs b WHERE b.$column = a.$column) '
      'AND a.$column IS NOT NULL '
      'ORDER BY a.$column',
    ).get();
    return [
      for (final r in rows)
        IndexStart(
          index: r.read<int>('idx'),
          surahId: r.read<int>('surah_id'),
          ayahNumber: r.read<int>('ayah'),
        ),
    ];
  }

  /// All translation editions, in the pipeline's global display order.
  ///
  /// Ordered by `sortOrder`, not by id: id comes from `cur.lastrowid` upstream
  /// and shifts whenever an edition is inserted into or reordered in
  /// `sources.yaml`, which would silently reshuffle the reader's page.
  /// `sortOrder` is the deliberate order (Urdu first), and the picker's
  /// language grouping falls out of it.
  Future<List<ResourceRow>> translationResources() => (select(resources)
        ..where((r) => r.type.equals('translation'))
        ..orderBy([
          (r) => OrderingTerm.asc(r.sortOrder),
          (r) => OrderingTerm.asc(r.id),
        ]))
      .get();
}

/// Where an index value (juz/hizb/page/ruku) first begins.
class IndexStart {
  const IndexStart({
    required this.index,
    required this.surahId,
    required this.ayahNumber,
  });

  final int index;
  final int surahId;
  final int ayahNumber;
}

LazyDatabase _openFile(File file) =>
    LazyDatabase(() async => NativeDatabase.createInBackground(file));
