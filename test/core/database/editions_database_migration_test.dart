import 'dart:io';

import 'package:al_quran/core/database/editions_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// This is the one database in the app with real existing-user data at stake:
/// unlike the bundled quran.db (wholesale-replaced on every seed refresh),
/// EditionsDatabase holds a reader's already-downloaded editions and must
/// survive schema changes in place. This pins the v1 -> v2 migration that adds
/// `credit_name`/`experimental` (added for the data-driven credit/Experimental
/// pill work) does not throw and degrades gracefully for a pre-existing row.
void main() {
  test('a v1 database with an existing row upgrades to v2 without data loss',
      () async {
    final tmp = Directory.systemTemp.createTempSync('editions_migration_test');
    final file = File('${tmp.path}/editions.db');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    // Build a v1-shape database by hand (the shape before credit_name /
    // experimental existed), with one already-installed edition — exactly
    // what a real device has before this app update lands.
    final raw = sq.sqlite3.open(file.path);
    raw
      ..execute('''
        CREATE TABLE installed_editions (
          slug TEXT NOT NULL,
          type TEXT NOT NULL,
          language_code TEXT NOT NULL,
          name TEXT NOT NULL,
          native_name TEXT,
          author TEXT,
          direction TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          license TEXT,
          source_url TEXT,
          ayah_count INTEGER NOT NULL DEFAULT 0,
          bytes INTEGER NOT NULL DEFAULT 0,
          sha256 TEXT,
          installed_at INTEGER NOT NULL,
          PRIMARY KEY (slug)
        )
      ''')
      ..execute('''
        CREATE TABLE edition_texts (
          slug TEXT NOT NULL,
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          content TEXT NOT NULL,
          PRIMARY KEY (slug, surah, ayah)
        )
      ''')
      ..execute('''
        INSERT INTO installed_editions
          (slug, type, language_code, name, author, sort_order,
           ayah_count, bytes, installed_at)
        VALUES
          ('hi-ahsanul-kalam', 'translation', 'hi', 'Ahsanul Kalam',
           'Shaikh Muhammad Rais Qureshi', 21, 6236, 2900000, 1735000000000)
      ''')
      ..execute('PRAGMA user_version = 1');
    raw.close();

    final db = EditionsDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db.installed();

    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.slug, 'hi-ahsanul-kalam');
    expect(row.author, 'Shaikh Muhammad Rais Qureshi');
    // The new columns degrade gracefully for a pre-existing row: no crash,
    // and the values resolve to exactly today's display (author/name
    // fallback, no pill) until this edition is reinstalled/updated.
    expect(row.creditName, isNull);
    expect(row.experimental, 0);
  });
}
