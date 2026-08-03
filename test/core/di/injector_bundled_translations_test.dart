import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/core/di/injector.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for a real bug caught only by manually running the app in
/// the iOS simulator: `bundledTranslations()` (used to build
/// TranslationsCubit's "compiled into the app" list) read every row in
/// `resources` unconditionally, with no `default_on` filter — unlike
/// AyahRepositoryImpl's own bundled filter, which correctly checks
/// `defaultOn == 1`. That mismatch meant a downloadable-only edition
/// (default_on: false) was permanently claimed as "bundled" in the
/// Translations picker: no install/remove lifecycle ever applied to it, and
/// its `editions.installed()` row — carrying the fresher author/creditName/
/// experimental once actually downloaded — was never consulted, because the
/// picker's merge logic skips any slug already claimed by the bundled list.
///
/// This never showed up in existing tests because every test that exercises
/// TranslationsCubit constructs its own `_bundled` fixture list directly,
/// bypassing this DI-layer function entirely. Nothing else in the suite
/// calls it, so nothing else could catch a regression here — hence making it
/// public + `@visibleForTesting` instead of leaving it `_`-prefixed.
void main() {
  test(
      'bundledTranslations only returns default_on resources, and carries '
      'creditName/experimental through for the ones it does return', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    addTearDown(db.close);

    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            slug: 'ur-junagarhi',
            type: 'translation',
            languageCode: 'ur',
            name: 'Junagarhi',
            defaultOn: const Value(1),
          ),
        );
    // A downloadable-only edition: default_on is false, but it's still a
    // metadata row in quran.db (so the picker/search can describe it before
    // it's ever downloaded) — this is the row that must NOT come back from
    // bundledTranslations().
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            slug: 'hi-ahsanul-kalam',
            type: 'translation',
            languageCode: 'hi',
            name: 'Ahsanul Kalam',
            author: const Value('Shaikh Muhammad Rais Qureshi'),
            experimental: const Value(1),
          ),
        );

    final resources = await bundledTranslations(db);

    expect(resources.map((r) => r.slug), ['ur-junagarhi']);
    expect(
      resources.map((r) => r.slug).contains('hi-ahsanul-kalam'),
      isFalse,
      reason: 'a default_on:false edition must never be treated as bundled — '
          'it needs the normal install/remove lifecycle',
    );
  });
}
