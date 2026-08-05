import 'package:equatable/equatable.dart';

import 'tafsir_resource.dart';

class TafsirCatalogueEntry extends Equatable {
  const TafsirCatalogueEntry({
    required this.slug,
    required this.languageCode,
    required this.name,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.uncompressedBytes,
    required this.uncompressedSha256,
    required this.ayahCount,
    required this.textGroupCount,
    this.nativeName,
    this.author,
    this.direction = 'ltr',
    this.sortOrder = 0,
    this.license,
    this.sourceUrl,
    this.creditName,
    this.abridged = false,
  });

  factory TafsirCatalogueEntry.fromJson(Map<String, dynamic> json) =>
      TafsirCatalogueEntry(
        slug: json['slug'] as String,
        languageCode: json['lang'] as String,
        name: json['name'] as String,
        nativeName: json['nativeName'] as String?,
        author: json['author'] as String?,
        direction: json['direction'] as String? ?? 'ltr',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        license: json['license'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        creditName: json['creditName'] as String?,
        abridged: json['abridged'] as bool? ?? false,
        ayahCount: (json['ayahCount'] as num?)?.toInt() ?? 0,
        textGroupCount: (json['textGroupCount'] as num?)?.toInt() ?? 0,
        file: json['file'] as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String,
        uncompressedBytes: (json['uncompressedBytes'] as num?)?.toInt() ?? 0,
        uncompressedSha256: json['uncompressedSha256'] as String? ?? '',
      );

  final String slug;
  final String languageCode;
  final String name;
  final String? nativeName;
  final String? author;
  final String direction;
  final int sortOrder;
  final String? license;
  final String? sourceUrl;
  final String? creditName;
  final bool abridged;
  final int ayahCount;
  final int textGroupCount;
  final String file;
  final int bytes;
  final String sha256;
  final int uncompressedBytes;
  final String uncompressedSha256;

  TafsirResource toResource({DateTime? installedAt}) => TafsirResource(
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
        bytes: uncompressedBytes,
        sha256: sha256,
        installedAt: installedAt,
      );

  @override
  List<Object?> get props => [slug, sha256];
}

class TafsirCatalogue extends Equatable {
  const TafsirCatalogue({
    required this.resources,
    this.generatedAt,
    this.dbVersion,
  });

  factory TafsirCatalogue.fromJson(Map<String, dynamic> json) =>
      TafsirCatalogue(
        generatedAt: json['generatedAt'] as String?,
        dbVersion: json['dbVersion'] as String?,
        resources: [
          for (final e in (json['tafsir'] as List? ?? const []))
            TafsirCatalogueEntry.fromJson(e as Map<String, dynamic>),
        ],
      );

  final List<TafsirCatalogueEntry> resources;
  final String? generatedAt;
  final String? dbVersion;

  @override
  List<Object?> get props => [resources, generatedAt, dbVersion];
}
