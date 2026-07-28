import 'dart:convert';
import 'dart:io';

import 'package:al_quran/core/database/editions_database.dart';
import 'package:al_quran/features/translations/data/repositories/edition_repository_impl.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// Installing a downloaded edition is the one place where unverified bytes could
/// become scripture on a reader's screen. These tests pin the checks that stop
/// that, and the separation that stops an app update from wiping downloads.
void main() {
  late Directory tmp;
  late EditionsDatabase db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('editions_test');
    db = EditionsDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Build a real edition artifact, exactly as build_editions.py emits one.
  List<int> buildArtifact({
    String slug = 'hi-ahsanul-kalam',
    int verses = 7,
    String? declaredSlug,
  }) {
    final file = File('${tmp.path}/build-$slug.db');
    if (file.existsSync()) file.deleteSync();
    final edb = sq.sqlite3.open(file.path);
    edb
      ..execute('CREATE TABLE edition (slug TEXT PRIMARY KEY, name TEXT)')
      ..execute(
        'CREATE TABLE texts (surah INTEGER, ayah INTEGER, text TEXT, '
        'PRIMARY KEY (surah, ayah))',
      )
      ..execute(
        "INSERT INTO edition VALUES ('${declaredSlug ?? slug}', 'Ahsanul Kalam')",
      );
    for (var i = 1; i <= verses; i++) {
      edb.execute("INSERT INTO texts VALUES (1, $i, 'verse $i')");
    }
    edb.close();
    final raw = file.readAsBytesSync();
    file.deleteSync();
    return gzip.encode(raw);
  }

  CatalogueEntry entryFor(
    List<int> gz, {
    String slug = 'hi-ahsanul-kalam',
    String? overrideSha,
  }) {
    final raw = gzip.decode(gz);
    return CatalogueEntry(
      slug: slug,
      type: 'translation',
      languageCode: 'hi',
      name: 'Ahsanul Kalam',
      nativeName: 'हिन्दी',
      author: 'Rais Qureshi',
      direction: 'ltr',
      sortOrder: 21,
      ayahCount: 7,
      file: '$slug.db.gz',
      bytes: gz.length,
      sha256: overrideSha ?? sha256.convert(gz).toString(),
      uncompressedBytes: raw.length,
      uncompressedSha256: sha256.convert(raw).toString(),
    );
  }

  EditionRepositoryImpl repoServing(List<int> body, {int status = 200}) {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('catalogue.json')) {
        return http.Response(json.encode({'editions': <Object>[]}), 200);
      }
      return http.Response.bytes(body, status);
    });
    return EditionRepositoryImpl(
      db: db,
      supportDir: tmp,
      catalogueUrl: Uri.parse('https://example.test/editions/catalogue.json'),
      client: client,
    );
  }

  test('a good artifact installs and its verses are readable', () async {
    final gz = buildArtifact();
    final repo = repoServing(gz);

    await repo.install(entryFor(gz));

    final installed = await repo.installed();
    expect(installed, hasLength(1));
    expect(installed.single.slug, 'hi-ahsanul-kalam');
    expect(installed.single.ayahCount, 7);
    expect(await db.textsForSurah('hi-ahsanul-kalam', 1), hasLength(7));
  });

  test('a corrupted download is rejected and installs nothing', () async {
    final gz = buildArtifact();
    // The catalogue says one thing; the bytes are another. This is the case a
    // digest exists for: truncation looks exactly like a short edition.
    final entry = entryFor(gz, overrideSha: 'a' * 64);
    final repo = repoServing(gz);

    await expectLater(
      repo.install(entry),
      throwsA(isA<EditionIntegrityException>()),
    );
    expect(await repo.installed(), isEmpty);
    expect(await db.textsForSurah('hi-ahsanul-kalam', 1), isEmpty);
  });

  test('a truncated download is rejected', () async {
    final gz = buildArtifact();
    final entry = entryFor(gz); // digests describe the WHOLE file
    final repo = repoServing(gz.sublist(0, gz.length ~/ 2));

    await expectLater(
      repo.install(entry),
      throwsA(isA<EditionIntegrityException>()),
    );
    expect(await repo.installed(), isEmpty);
  });

  test('an artifact declaring a different slug is rejected', () async {
    // Hashes fine, but it is not the edition the reader asked for. Installing
    // it would put one translation on screen under another's name.
    final gz = buildArtifact(declaredSlug: 'ur-junagarhi');
    final repo = repoServing(gz);

    await expectLater(
      repo.install(entryFor(gz)),
      throwsA(isA<EditionIntegrityException>()),
    );
    expect(await repo.installed(), isEmpty);
  });

  test('a failed install leaves no temp file behind', () async {
    final gz = buildArtifact();
    final repo = repoServing(gz);
    await expectLater(
      repo.install(entryFor(gz, overrideSha: 'b' * 64)),
      throwsA(isA<EditionIntegrityException>()),
    );
    expect(
      tmp.listSync().where((f) => f.path.endsWith('.tmp.db')),
      isEmpty,
    );
  });

  test('reinstalling replaces rather than duplicating', () async {
    final gz = buildArtifact(verses: 7);
    await repoServing(gz).install(entryFor(gz));

    final gz2 = buildArtifact(verses: 3); // a newer, different build
    await repoServing(gz2).install(entryFor(gz2));

    final installed = await repoServing(gz2).installed();
    expect(installed, hasLength(1));
    expect(await db.textsForSurah('hi-ahsanul-kalam', 1), hasLength(3));
  });

  test('removing an edition drops its metadata and its text', () async {
    final gz = buildArtifact();
    final repo = repoServing(gz);
    await repo.install(entryFor(gz));

    await repo.remove('hi-ahsanul-kalam');

    expect(await repo.installed(), isEmpty);
    expect(await db.textsForSurah('hi-ahsanul-kalam', 1), isEmpty);
  });

  test('the catalogue falls back to its cache when offline', () async {
    final catalogue = json.encode({
      'editions': [
        {
          'slug': 'hi-ahsanul-kalam',
          'lang': 'hi',
          'name': 'Ahsanul Kalam',
          'file': 'hi-ahsanul-kalam.db.gz',
          'sha256': 'x',
        },
      ],
    });
    var online = true;
    final client = MockClient((req) async {
      if (!online) throw const SocketException('offline');
      return http.Response(catalogue, 200);
    });
    final repo = EditionRepositoryImpl(
      db: db,
      supportDir: tmp,
      catalogueUrl: Uri.parse('https://example.test/editions/catalogue.json'),
      client: client,
    );

    expect((await repo.catalogue()).editions, hasLength(1));

    // Offline is the normal state for this app, not an error: the screen must
    // still list what is on offer rather than appearing empty.
    online = false;
    expect((await repo.catalogue()).editions, hasLength(1));
  });

  test('offline with no cache at all reports a download failure', () async {
    final client = MockClient(
      (_) async => throw const SocketException('nope'),
    );
    final repo = EditionRepositoryImpl(
      db: db,
      supportDir: tmp,
      catalogueUrl: Uri.parse('https://example.test/editions/catalogue.json'),
      client: client,
    );
    await expectLater(
      repo.catalogue(),
      throwsA(isA<EditionDownloadException>()),
    );
  });
}
