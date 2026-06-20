import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The bundled, fully-offline seed database (compiled by the alquran-data
/// pipeline and shipped as an asset). It is copied to a writable location on
/// first launch; the tables already exist and are populated, so the Drift
/// migration is a no-op (see [migration]).
@DriftDatabase(tables: [Surahs, Ayahs, Resources, Translations, DbMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

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

  Future<List<AyahRow>> ayahsForSurah(int surahId) =>
      (select(ayahs)
            ..where((a) => a.surahId.equals(surahId))
            ..orderBy([(a) => OrderingTerm.asc(a.ayahNumber)]))
          .get();

  /// Ayahs of an index range (juz/hizb/page/ruku), in mushaf order. These
  /// indices are global and monotonic, so ordering by the running [Ayahs.id]
  /// yields the correct reading sequence even across surah boundaries.
  Future<List<AyahRow>> ayahsForJuz(int n) => _ayahsByGlobalIndex(ayahs.juzNumber, n);
  Future<List<AyahRow>> ayahsForHizb(int n) => _ayahsByGlobalIndex(ayahs.hizbNumber, n);
  Future<List<AyahRow>> ayahsForPage(int n) => _ayahsByGlobalIndex(ayahs.pageNumber, n);
  Future<List<AyahRow>> ayahsForRuku(int n) => _ayahsByGlobalIndex(ayahs.rukuNumber, n);

  Future<List<AyahRow>> _ayahsByGlobalIndex(GeneratedColumn<int> col, int n) =>
      (select(ayahs)
            ..where((a) => col.equals(n))
            ..orderBy([(a) => OrderingTerm.asc(a.id)]))
          .get();

  /// Translations for an arbitrary set of ayahs, keyed by ayahId -> (resourceId
  /// -> text). Used when a reader section spans surahs (juz/hizb/page/ruku).
  Future<Map<int, Map<int, String>>> translationsForAyahIds(
    List<int> ayahIds,
  ) async {
    if (ayahIds.isEmpty) return {};
    final rows = await (select(translations)
          ..where((t) => t.ayahId.isIn(ayahIds)))
        .get();
    final out = <int, Map<int, String>>{};
    for (final t in rows) {
      out.putIfAbsent(t.ayahId, () => {})[t.resourceId] = t.textContent;
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

  /// All active translation resources (MVP: Urdu + Hindi), ordered by id.
  Future<List<ResourceRow>> translationResources() =>
      (select(resources)..where((r) => r.type.equals('translation'))).get();

  /// Translations for one ayah keyed by resource id.
  Future<Map<int, String>> translationsForAyah(int ayahId) async {
    final rows = await (select(translations)
          ..where((t) => t.ayahId.equals(ayahId)))
        .get();
    return {for (final r in rows) r.resourceId: r.textContent};
  }

  /// All translations for a surah in one query, keyed by ayahId -> (resourceId
  /// -> text). Avoids a per-ayah round trip when rendering a whole surah.
  Future<Map<int, Map<int, String>>> translationsForSurah(int surahId) async {
    final query = select(translations).join([
      innerJoin(ayahs, ayahs.id.equalsExp(translations.ayahId)),
    ])
      ..where(ayahs.surahId.equals(surahId));
    final rows = await query.get();
    final out = <int, Map<int, String>>{};
    for (final row in rows) {
      final t = row.readTable(translations);
      out.putIfAbsent(t.ayahId, () => {})[t.resourceId] = t.textContent;
    }
    return out;
  }
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'quran.db'));

    if (!await file.exists()) {
      // First launch: unpack the bundled seed DB into writable storage.
      final blob = await rootBundle.load('assets/db/quran.db');
      final bytes = blob.buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes);
      await file.writeAsBytes(bytes, flush: true);
    }

    return NativeDatabase.createInBackground(file);
  });
}
