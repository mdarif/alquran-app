import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/tafsir/domain/entities/tafsir_entry.dart';
import '../../features/tafsir/domain/entities/tafsir_resource.dart';

Future<File> tafsirDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'tafsir.db'));
}

class TafsirDatabase {
  TafsirDatabase(this.file);

  final File file;

  Database _open() {
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
CREATE TABLE IF NOT EXISTS tafsir_resources (
  slug TEXT PRIMARY KEY,
  language_code TEXT NOT NULL,
  name TEXT NOT NULL,
  native_name TEXT,
  author TEXT,
  direction TEXT NOT NULL DEFAULT 'ltr',
  sort_order INTEGER NOT NULL DEFAULT 0,
  license TEXT,
  source_url TEXT,
  credit_name TEXT,
  abridged INTEGER NOT NULL DEFAULT 0,
  ayah_count INTEGER NOT NULL DEFAULT 0,
  bytes INTEGER NOT NULL DEFAULT 0,
  sha256 TEXT,
  installed_at TEXT NOT NULL
)''');
    db.execute('''
CREATE TABLE IF NOT EXISTS tafsir_entries (
  resource_slug TEXT NOT NULL,
  ayah_key TEXT NOT NULL,
  group_ayah_key TEXT NOT NULL,
  from_ayah TEXT NOT NULL,
  to_ayah TEXT NOT NULL,
  ayah_keys TEXT NOT NULL,
  text TEXT,
  PRIMARY KEY(resource_slug, ayah_key),
  FOREIGN KEY(resource_slug) REFERENCES tafsir_resources(slug) ON DELETE CASCADE
)''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tafsir_entries_group '
      'ON tafsir_entries(resource_slug, group_ayah_key)',
    );
    return db;
  }

  Future<List<TafsirResource>> installed() async {
    final db = _open();
    try {
      final rows = db.select(
        'SELECT * FROM tafsir_resources ORDER BY sort_order, language_code, slug',
      );
      return [
        for (final r in rows)
          TafsirResource(
            slug: r['slug'] as String,
            languageCode: r['language_code'] as String,
            name: r['name'] as String,
            nativeName: r['native_name'] as String?,
            author: r['author'] as String?,
            direction: r['direction'] as String,
            sortOrder: r['sort_order'] as int,
            license: r['license'] as String?,
            sourceUrl: r['source_url'] as String?,
            creditName: r['credit_name'] as String?,
            abridged: (r['abridged'] as int) == 1,
            ayahCount: r['ayah_count'] as int,
            bytes: r['bytes'] as int,
            sha256: r['sha256'] as String?,
            installedAt: DateTime.tryParse(r['installed_at'] as String),
          ),
      ];
    } finally {
      db.close();
    }
  }

  Future<void> replaceResource({
    required TafsirResource resource,
    required List<TafsirEntry> entries,
  }) async {
    final db = _open();
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        final deleteEntries = db.prepare(
          'DELETE FROM tafsir_entries WHERE resource_slug = ?',
        );
        final deleteResource = db.prepare(
          'DELETE FROM tafsir_resources WHERE slug = ?',
        );
        final insertResource = db.prepare('''
INSERT INTO tafsir_resources(
  slug, language_code, name, native_name, author, direction, sort_order,
  license, source_url, credit_name, abridged, ayah_count, bytes, sha256,
  installed_at
) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''');
        final insertEntry = db.prepare('''
INSERT INTO tafsir_entries(
  resource_slug, ayah_key, group_ayah_key, from_ayah, to_ayah, ayah_keys, text
) VALUES (?,?,?,?,?,?,?)''');
        try {
          deleteEntries.execute([resource.slug]);
          deleteResource.execute([resource.slug]);
          insertResource.execute([
            resource.slug,
            resource.languageCode,
            resource.name,
            resource.nativeName,
            resource.author,
            resource.direction,
            resource.sortOrder,
            resource.license,
            resource.sourceUrl,
            resource.creditName,
            resource.abridged ? 1 : 0,
            resource.ayahCount,
            resource.bytes,
            resource.sha256,
            (resource.installedAt ?? DateTime.now()).toIso8601String(),
          ]);
          for (final entry in entries) {
            insertEntry.execute([
              resource.slug,
              entry.ayahKey,
              entry.groupAyahKey,
              entry.fromAyah,
              entry.toAyah,
              entry.ayahKeys.join(','),
              entry.text,
            ]);
          }
        } finally {
          deleteEntries.close();
          deleteResource.close();
          insertResource.close();
          insertEntry.close();
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async {
    final db = _open();
    final key = '$surah:$ayah';
    try {
      final row = db.select(
        'SELECT * FROM tafsir_entries WHERE resource_slug = ? AND ayah_key = ?',
        [slug, key],
      );
      if (row.isEmpty) return null;
      final first = row.first;
      final text = first['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        return _entryFromRow(slug, first);
      }
      final groupKey = first['group_ayah_key'] as String;
      final group = db.select(
        'SELECT * FROM tafsir_entries '
        'WHERE resource_slug = ? AND ayah_key = ? LIMIT 1',
        [slug, groupKey],
      );
      if (group.isEmpty) return null;
      return _entryFromRow(slug, group.first, requestedAyahKey: key);
    } finally {
      db.close();
    }
  }
}

TafsirEntry _entryFromRow(
  String slug,
  Row row, {
  String? requestedAyahKey,
}) {
  final body = (row['text'] as String?)?.trim();
  if (body == null || body.isEmpty) {
    throw StateError('tafsir group row has no text');
  }
  return TafsirEntry(
    resource: slug,
    ayahKey: requestedAyahKey ?? row['ayah_key'] as String,
    groupAyahKey: row['group_ayah_key'] as String,
    fromAyah: row['from_ayah'] as String,
    toAyah: row['to_ayah'] as String,
    ayahKeys: (row['ayah_keys'] as String)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    text: body,
  );
}
