import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sq;

import '../../../../core/database/editions_database.dart';
import '../../domain/entities/catalogue_entry.dart';
import '../../domain/entities/installed_edition.dart';
import '../../domain/repositories/edition_repository.dart';

/// Downloads editions from the artifact host and installs them locally.
///
/// The remote side is `alquran-data/pipeline/build_editions.py` → R2:
/// `catalogue.json` plus one gzipped SQLite file per edition, named by slug.
///
/// Two invariants shape everything here:
///
/// 1. **Nothing installs without matching its digest.** The catalogue records a
///    sha256 for the transferred file and another for the expanded one; both are
///    checked. A truncated download is otherwise indistinguishable from a short
///    edition, and it would render blank verses rather than raise anything.
/// 2. **Downloads live in `editions.db`, never in `quran.db`.** The bundled DB
///    is overwritten whenever its version marker changes, so anything written
///    there vanishes on the next app update. → [EditionsDatabase]
class EditionRepositoryImpl implements EditionRepository {
  EditionRepositoryImpl({
    required EditionsDatabase db,
    required Directory supportDir,
    required Uri catalogueUrl,
    http.Client? client,
  })  : _db = db,
        _supportDir = supportDir,
        _catalogueUrl = catalogueUrl,
        _client = client ?? http.Client();

  final EditionsDatabase _db;
  final Directory _supportDir;
  final Uri _catalogueUrl;
  final http.Client _client;

  static const String _cacheFile = 'catalogue.json';

  File get _cachedCatalogue => File(p.join(_supportDir.path, _cacheFile));

  @override
  Future<EditionCatalogue> catalogue({bool forceRefresh = false}) async {
    try {
      final res = await _client.get(_catalogueUrl);
      if (res.statusCode != 200) {
        throw EditionDownloadException('catalogue HTTP ${res.statusCode}');
      }
      final body = utf8.decode(res.bodyBytes);
      // Cache before parsing fails on us, so a malformed *newer* catalogue
      // can't strand the reader with nothing.
      final parsed = EditionCatalogue.fromJson(
        json.decode(body) as Map<String, dynamic>,
      );
      await _cachedCatalogue.parent.create(recursive: true);
      await _cachedCatalogue.writeAsString(body);
      return parsed;
    } catch (e) {
      // Offline is the normal case for this app, not an error state: fall back
      // to the last catalogue we saw so the screen still lists what is on
      // offer. Only a first run with no cache genuinely has nothing to show.
      if (await _cachedCatalogue.exists()) {
        try {
          return EditionCatalogue.fromJson(
            json.decode(await _cachedCatalogue.readAsString())
                as Map<String, dynamic>,
          );
        } catch (_) {
          // Cache unreadable — fall through to the error below.
        }
      }
      if (e is EditionDownloadException) rethrow;
      throw EditionDownloadException('$e');
    }
  }

  @override
  Future<List<InstalledEdition>> installed() async {
    final rows = await _db.installed();
    return [
      for (final r in rows)
        InstalledEdition(
          slug: r.slug,
          type: r.type,
          languageCode: r.languageCode,
          name: r.name,
          nativeName: r.nativeName,
          author: r.author,
          direction: r.direction,
          sortOrder: r.sortOrder,
          license: r.license,
          sourceUrl: r.sourceUrl,
          ayahCount: r.ayahCount,
          bytes: r.bytes,
          sha256: r.sha256,
          installedAt: r.installedAt,
        ),
    ];
  }

  @override
  Future<void> install(
    CatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    final url = _catalogueUrl.resolve(entry.file);
    final gz = await _download(url, entry, onProgress);

    // Check what we actually received before expanding it.
    final gotGz = sha256.convert(gz).toString();
    if (gotGz != entry.sha256) {
      throw EditionIntegrityException(
        entry.slug,
        'download digest mismatch: expected ${entry.sha256}, got $gotGz',
      );
    }

    final raw = gzip.decode(gz);

    // And check the expanded file before it reaches the reader. Older
    // catalogues may not carry this digest; skip rather than fail closed on a
    // field that simply predates the check.
    if (entry.uncompressedSha256.isNotEmpty) {
      final gotRaw = sha256.convert(raw).toString();
      if (gotRaw != entry.uncompressedSha256) {
        throw EditionIntegrityException(
          entry.slug,
          'expanded digest mismatch: expected ${entry.uncompressedSha256}, '
          'got $gotRaw',
        );
      }
    }

    // sqlite3 needs a real file; write to a temp path and always clean it up so
    // a failed install leaves nothing behind.
    final tmp = File(p.join(_supportDir.path, '${entry.slug}.tmp.db'));
    await tmp.parent.create(recursive: true);
    await tmp.writeAsBytes(raw, flush: true);
    try {
      final texts = _readEditionFile(tmp, entry);
      await _db.replaceEdition(
        InstalledEditionsCompanion.insert(
          slug: entry.slug,
          type: entry.type,
          languageCode: entry.languageCode,
          name: entry.name,
          nativeName: Value(entry.nativeName),
          author: Value(entry.author),
          direction: Value(entry.direction),
          sortOrder: Value(entry.sortOrder),
          license: Value(entry.license),
          sourceUrl: Value(entry.sourceUrl),
          ayahCount: Value(texts.length),
          bytes: Value(raw.length),
          sha256: Value(entry.sha256),
          installedAt: DateTime.now(),
        ),
        texts,
      );
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> remove(String slug) => _db.removeEdition(slug);

  /// Fetch the artifact, reporting progress where the server gives a length.
  Future<List<int>> _download(
    Uri url,
    CatalogueEntry entry,
    void Function(double)? onProgress,
  ) async {
    final req = http.Request('GET', url);
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw EditionDownloadException(
        '${entry.slug}: HTTP ${res.statusCode} from $url',
      );
    }
    // Prefer the catalogue's size over Content-Length: the catalogue is the
    // thing we verify against, and a proxy can rewrite the header.
    final total = entry.bytes > 0 ? entry.bytes : (res.contentLength ?? 0);
    final bytes = <int>[];
    await for (final chunk in res.stream) {
      bytes.addAll(chunk);
      if (onProgress != null && total > 0) {
        onProgress((bytes.length / total).clamp(0.0, 1.0));
      }
    }
    return bytes;
  }

  /// Read `texts` out of a downloaded edition file.
  ///
  /// Guards the shape as well as the digest: a file that hashes correctly but
  /// carries the wrong slug, or no rows, must not install. Both would otherwise
  /// present as an edition that renders nothing.
  List<EditionTextsCompanion> _readEditionFile(
    File file,
    CatalogueEntry entry,
  ) {
    final db = sq.sqlite3.open(file.path, mode: sq.OpenMode.readOnly);
    try {
      final meta = db.select('SELECT slug FROM edition LIMIT 1');
      if (meta.isEmpty) {
        throw EditionIntegrityException(entry.slug, 'no edition metadata row');
      }
      final fileSlug = meta.first['slug'] as String?;
      if (fileSlug != entry.slug) {
        throw EditionIntegrityException(
          entry.slug,
          'artifact declares slug "$fileSlug"',
        );
      }
      final rows = db.select('SELECT surah, ayah, text FROM texts');
      if (rows.isEmpty) {
        throw EditionIntegrityException(entry.slug, 'artifact has no verses');
      }
      return [
        for (final r in rows)
          EditionTextsCompanion.insert(
            slug: entry.slug,
            surah: r['surah'] as int,
            ayah: r['ayah'] as int,
            content: r['text'] as String,
          ),
      ];
    } finally {
      db.close();
    }
  }
}
