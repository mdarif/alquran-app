// DATABASE & PIPELINE TESTS for the Hijri anchor-table correction system.
//
// Exercises `HijriAnchorRepository` against a REAL Drift/SQLite engine
// (in-memory, so it's fast and hermetic — no file I/O, safe for CI). Two
// scenarios matter operationally:
//   1. Priority override — a DB anchor is authoritative. It must be used
//      as-is, never blended with or overridden by the tabular fallback.
//   2. Graceful degradation — a corrupt/missing anchor table (an older
//      bundled `quran.db` that predates this feature, or any read failure)
//      must never crash the app or block the Hijri date from rendering; it
//      must fall back to "no correction" silently.
//
// Schema under test (`HijriAnchorPoints` in lib/core/database/tables.dart),
// reproduced here for reference — this is what the alquran-data pipeline
// must emit into `quran.db` for anchors to reach the app:
//
//   CREATE TABLE hijri_anchor_points (
//     gregorian_date TEXT NOT NULL,     -- 'YYYY-MM-DD', from-date (inclusive)
//     region TEXT NOT NULL,             -- e.g. 'PK', 'IN'
//     correction_days INTEGER NOT NULL, -- applied to the tabular result
//     source TEXT,                      -- e.g. 'Ruet-e-Hilal Committee PK'
//     PRIMARY KEY (gregorian_date, region)
//   );
import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/core/hijri/hijri_anchor_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Bypasses the (deliberately no-op) migration strategy so every table
    // that AppDatabase knows about — including HijriAnchorPoints — exists in
    // this fresh in-memory instance, mirroring a fully-migrated device DB.
    await db.createMigrator().createAll();
  });
  tearDown(() => db.close());

  /// CI-friendly mock data helper: inserts one verified anchor row.
  Future<void> seedAnchor({
    required String date,
    required int correctionDays,
    String region = 'PK',
    String? source,
  }) =>
      db.into(db.hijriAnchorPoints).insert(
            HijriAnchorPointsCompanion.insert(
              gregorianDate: date,
              region: region,
              correctionDays: correctionDays,
              source: Value(source),
            ),
          );

  group('priority override', () {
    test(
      'a DB anchor is used strictly as-is, ignoring the tabular fallback '
      'entirely (not averaged, not only applied when it agrees)',
      () async {
        // Seed a deliberately unusual correction (+3) that no plausible
        // fallback algorithm would ever produce, to prove it passes through
        // untouched rather than being clamped/blended.
        await seedAnchor(
          date: '2026-07-15',
          correctionDays: 3,
          source: 'Ruet-e-Hilal Committee PK',
        );

        final repo = HijriAnchorRepository(db);
        await repo.preload();

        expect(repo.correctionDaysFor(DateTime(2026, 7, 29)), 3);
      },
    );

    test(
      'the most recent applicable anchor wins over older ones for the same '
      'region',
      () async {
        await seedAnchor(date: '2026-01-01', correctionDays: 1);
        await seedAnchor(date: '2026-07-15', correctionDays: 0);

        final repo = HijriAnchorRepository(db);
        await repo.preload();

        expect(repo.correctionDaysFor(DateTime(2026, 8, 1)), 0);
      },
    );

    test(
        'a region with no matching anchor row falls back to 0, not '
        "another region's value", () async {
      await seedAnchor(date: '2026-07-01', correctionDays: 1, region: 'IN');

      final repo = HijriAnchorRepository(db);
      await repo.preload();

      expect(
        repo.correctionDaysFor(DateTime(2026, 7, 29), region: 'PK'),
        0,
      );
    });
  });

  group('graceful degradation', () {
    test(
      'an empty anchor table (no rows yet synced) never crashes and '
      'resolves to the base algorithm (correction 0)',
      () async {
        final repo = HijriAnchorRepository(db);
        await repo.preload(); // table exists, zero rows

        expect(
          () => repo.correctionDaysFor(DateTime(2026, 7, 29)),
          returnsNormally,
        );
        expect(repo.correctionDaysFor(DateTime(2026, 7, 29)), 0);
      },
    );

    test(
      'a missing anchor table entirely (older bundled DB, pre-migration) '
      'degrades to correction 0 instead of throwing on preload',
      () async {
        // Simulates a `quran.db` shipped before this feature existed: every
        // OTHER table is created, but hijri_anchor_points never was.
        final legacyDb = AppDatabase.forTesting(NativeDatabase.memory());
        await legacyDb.customStatement('''
          CREATE TABLE surahs (
            id INTEGER NOT NULL PRIMARY KEY,
            name_arabic TEXT NOT NULL,
            name_english TEXT NOT NULL,
            revelation_place TEXT,
            total_ayahs INTEGER NOT NULL
          );
        '''); // deliberately no hijri_anchor_points table

        final repo = HijriAnchorRepository(legacyDb);

        await expectLater(repo.preload(), completes);
        expect(repo.correctionDaysFor(DateTime(2026, 7, 29)), 0);

        await legacyDb.close();
      },
    );

    test(
      'correctionDaysFor never returns null and never throws even before '
      'preload() has been called',
      () {
        final repo = HijriAnchorRepository(db);
        expect(
          repo.correctionDaysFor(DateTime(2026, 7, 29)),
          0,
        );
      },
    );

    test(
      'a corrupt row shape (simulated via a raw statement bypassing Drift '
      'validation is not representable — instead assert malformed DATES in a '
      'valid row degrade that row rather than aborting the whole preload)',
      () async {
        // A row with a non-ISO date string is a realistic pipeline bug
        // (e.g. locale-formatted date leaking through). One bad row should
        // not take down every other, correctly-formed anchor.
        await db.into(db.hijriAnchorPoints).insert(
              const HijriAnchorPointsCompanion(
                gregorianDate: Value('15/07/2026'), // malformed
                region: Value('PK'),
                correctionDays: Value(9), // must NOT leak through
              ),
            );
        // A second, well-formed anchor alongside the bad one.
        await seedAnchor(date: '2026-01-01', correctionDays: 2);

        final repo = HijriAnchorRepository(db);
        await repo.preload();

        // The malformed row contributes nothing (not 9, not a crash) …
        expect(
          () => repo.correctionDaysFor(DateTime(2026, 7, 29)),
          returnsNormally,
        );
        // … but the well-formed sibling row still resolves correctly, proving
        // one bad row doesn't discard the whole preloaded batch.
        expect(repo.correctionDaysFor(DateTime(2026, 7, 29)), 2);
      },
    );
  });
}
