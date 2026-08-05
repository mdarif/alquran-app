import 'package:equatable/equatable.dart';

/// One edition offered for download, as described by the remote catalogue.
///
/// Produced by `alquran-data/pipeline/build_editions.py` and served from R2.
/// The two digests are not redundant: [sha256] covers the **gzipped file that
/// is transferred** (so a truncated or corrupted download is caught before it
/// is expanded), and [uncompressedSha256] covers **the SQLite file that gets
/// installed** (so a bad expansion is caught before it reaches the reader).
/// A short edition renders blank verses rather than failing, so neither check
/// is optional.
class CatalogueEntry extends Equatable {
  const CatalogueEntry({
    required this.slug,
    required this.type,
    required this.languageCode,
    required this.name,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.uncompressedBytes,
    required this.uncompressedSha256,
    required this.ayahCount,
    this.nativeName,
    this.author,
    this.direction,
    this.sortOrder = 0,
    this.license,
    this.sourceUrl,
    this.creditName,
    this.experimental = false,
    this.visible = true,
  });

  factory CatalogueEntry.fromJson(Map<String, dynamic> json) => CatalogueEntry(
        slug: json['slug'] as String,
        type: json['type'] as String? ?? 'translation',
        languageCode: json['lang'] as String,
        name: json['name'] as String,
        nativeName: json['nativeName'] as String?,
        author: json['author'] as String?,
        direction: json['direction'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        license: json['license'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        // Older catalogues may not carry these fields; absent means "use
        // author, else name" and "not experimental" — the same defaults as
        // every edition that never sets them upstream.
        creditName: json['creditName'] as String?,
        experimental: json['experimental'] as bool? ?? false,
        visible: json['visible'] as bool? ?? true,
        ayahCount: (json['ayahCount'] as num?)?.toInt() ?? 0,
        file: json['file'] as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String,
        uncompressedBytes: (json['uncompressedBytes'] as num?)?.toInt() ?? 0,
        uncompressedSha256: json['uncompressedSha256'] as String? ?? '',
      );

  final String slug;
  final String type;
  final String languageCode;
  final String name;
  final String? nativeName;
  final String? author;
  final String? direction;
  final int sortOrder;
  final String? license;
  final String? sourceUrl;

  /// Short one-line display name for the reader credit + picker subtitle.
  /// Null means "use author, else name".
  final String? creditName;

  /// True = show the "Experimental" pill (unreviewed/pilot content).
  final bool experimental;

  /// Runtime catalogue switch. False hides this slug from the manager without
  /// changing the artifact or requiring an app release.
  final bool visible;

  final int ayahCount;

  /// Filename relative to the catalogue's own URL, e.g. `hi-ahsanul-kalam.db.gz`.
  final String file;

  /// Transfer size — what the reader is asked to download.
  final int bytes;
  final String sha256;

  /// Size on disk once expanded — what keeping it actually costs them.
  final int uncompressedBytes;
  final String uncompressedSha256;

  String get languageLabel =>
      nativeName?.trim().isNotEmpty == true ? nativeName! : languageCode;

  /// One-line credit shown in the Translations picker.
  String get displayCredit {
    final credit = creditName?.trim();
    if (credit != null && credit.isNotEmpty) return credit;
    final a = author?.trim();
    if (a != null && a.isNotEmpty) return a;
    return name;
  }

  @override
  List<Object?> get props => [slug, sha256, visible];
}

/// The remote catalogue: every edition available for download.
class EditionCatalogue extends Equatable {
  const EditionCatalogue({
    required this.editions,
    this.generatedAt,
    this.dbVersion,
  });

  factory EditionCatalogue.fromJson(Map<String, dynamic> json) =>
      EditionCatalogue(
        generatedAt: json['generatedAt'] as String?,
        dbVersion: json['dbVersion'] as String?,
        editions: [
          for (final e in (json['editions'] as List? ?? const []))
            CatalogueEntry.fromJson(e as Map<String, dynamic>),
        ],
      );

  final List<CatalogueEntry> editions;
  final String? generatedAt;
  final String? dbVersion;

  @override
  List<Object?> get props => [editions, generatedAt, dbVersion];
}
