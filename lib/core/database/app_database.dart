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
