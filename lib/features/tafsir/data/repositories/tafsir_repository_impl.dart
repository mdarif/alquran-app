import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sq;

import '../../../../core/database/tafsir_database.dart';
import '../../domain/entities/tafsir_catalogue_entry.dart';
import '../../domain/entities/tafsir_entry.dart';
import '../../domain/entities/tafsir_resource.dart';
import '../../domain/repositories/tafsir_repository.dart';

class TafsirRepositoryImpl implements TafsirRepository {
  TafsirRepositoryImpl({
    required TafsirDatabase db,
    required Directory supportDir,
    required Uri catalogueUrl,
    http.Client? client,
  })  : _db = db,
        _supportDir = supportDir,
        _catalogueUrl = catalogueUrl,
        _client = client ?? http.Client();

  final TafsirDatabase _db;
  final Directory _supportDir;
  final Uri _catalogueUrl;
  final http.Client _client;

  File get _cachedCatalogue =>
      File(p.join(_supportDir.path, 'tafsir-catalogue.json'));

  @override
  Future<TafsirCatalogue> catalogue() async {
    try {
      final res = await _client.get(_catalogueUrl);
      if (res.statusCode != 200) {
        throw TafsirDownloadException('catalogue HTTP ${res.statusCode}');
      }
      final body = utf8.decode(res.bodyBytes);
      final parsed = TafsirCatalogue.fromJson(
        json.decode(body) as Map<String, dynamic>,
      );
      await _cachedCatalogue.parent.create(recursive: true);
      await _cachedCatalogue.writeAsString(body);
      return parsed;
    } catch (e) {
      if (await _cachedCatalogue.exists()) {
        try {
          return TafsirCatalogue.fromJson(
            json.decode(await _cachedCatalogue.readAsString())
                as Map<String, dynamic>,
          );
        } catch (_) {}
      }
      if (e is TafsirDownloadException) rethrow;
      throw TafsirDownloadException('$e');
    }
  }

  @override
  Future<List<TafsirResource>> installed() => _db.installed();

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    final url = _catalogueUrl.resolve(entry.file);
    final gz = await _download(url, entry, onProgress);
    final gotGz = sha256.convert(gz).toString();
    if (gotGz != entry.sha256) {
      throw TafsirIntegrityException(
        entry.slug,
        'download digest mismatch: expected ${entry.sha256}, got $gotGz',
      );
    }
    final raw = gzip.decode(gz);
    if (entry.uncompressedSha256.isNotEmpty) {
      final gotRaw = sha256.convert(raw).toString();
      if (gotRaw != entry.uncompressedSha256) {
        throw TafsirIntegrityException(
          entry.slug,
          'expanded digest mismatch: expected ${entry.uncompressedSha256}, got $gotRaw',
        );
      }
    }

    final tmp = File(p.join(_supportDir.path, '${entry.slug}.tafsir.tmp.db'));
    await tmp.parent.create(recursive: true);
    await tmp.writeAsBytes(raw, flush: true);
    try {
      final entries = _readTafsirFile(tmp, entry);
      await _db.replaceResource(
        resource: entry.toResource(installedAt: DateTime.now()).copyWithBytes(
              raw.length,
            ),
        entries: entries,
      );
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) =>
      _db.entryForAyah(slug: slug, surah: surah, ayah: ayah);

  @override
  Future<void> remove(String slug) => _db.removeResource(slug);

  Future<List<int>> _download(
    Uri url,
    TafsirCatalogueEntry entry,
    void Function(double)? onProgress,
  ) async {
    final req = http.Request('GET', url);
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw TafsirDownloadException(
        '${entry.slug}: HTTP ${res.statusCode} from $url',
      );
    }
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

  List<TafsirEntry> _readTafsirFile(
    File file,
    TafsirCatalogueEntry entry,
  ) {
    final db = sq.sqlite3.open(file.path, mode: sq.OpenMode.readOnly);
    try {
      final meta = db.select('SELECT slug FROM tafsir_resource LIMIT 1');
      if (meta.isEmpty) {
        throw TafsirIntegrityException(entry.slug, 'no resource metadata row');
      }
      final fileSlug = meta.first['slug'] as String?;
      if (fileSlug != entry.slug) {
        throw TafsirIntegrityException(
          entry.slug,
          'artifact declares slug "$fileSlug"',
        );
      }
      final rows = db.select(
        'SELECT ayah_key, group_ayah_key, from_ayah, to_ayah, ayah_keys, text '
        'FROM tafsir_entries',
      );
      if (rows.length != entry.ayahCount) {
        throw TafsirIntegrityException(
          entry.slug,
          'artifact covers ${rows.length}/${entry.ayahCount} ayahs',
        );
      }
      return [
        for (final r in rows)
          TafsirEntry(
            resource: entry.slug,
            ayahKey: r['ayah_key'] as String,
            groupAyahKey: r['group_ayah_key'] as String,
            fromAyah: r['from_ayah'] as String,
            toAyah: r['to_ayah'] as String,
            ayahKeys: (r['ayah_keys'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
            text: (r['text'] as String?)?.trim() ?? '',
          ),
      ];
    } finally {
      db.close();
    }
  }
}

extension on TafsirResource {
  TafsirResource copyWithBytes(int bytes) => TafsirResource(
        slug: slug,
        languageCode: languageCode,
        name: name,
        nativeName: nativeName,
        author: author,
        direction: direction,
        sortOrder: sortOrder,
        license: license,
        sourceUrl: sourceUrl,
        creditName: creditName,
        abridged: abridged,
        ayahCount: ayahCount,
        bytes: bytes,
        sha256: this.sha256,
        installedAt: installedAt,
      );
}
