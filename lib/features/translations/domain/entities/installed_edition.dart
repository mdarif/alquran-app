import 'package:equatable/equatable.dart';

import '../../../reader/domain/entities/translation_resource.dart';

/// A downloaded edition present on this device.
class InstalledEdition extends Equatable {
  const InstalledEdition({
    required this.slug,
    required this.type,
    required this.languageCode,
    required this.name,
    required this.installedAt,
    this.nativeName,
    this.author,
    this.direction,
    this.sortOrder = 0,
    this.license,
    this.sourceUrl,
    this.ayahCount = 0,
    this.bytes = 0,
    this.sha256,
  });

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
  final int ayahCount;
  final int bytes;
  final String? sha256;
  final DateTime installedAt;

  /// Present the same way a bundled edition is, so the reader and its pickers
  /// need not know where a given text came from.
  TranslationResource toResource() => TranslationResource(
        // Downloaded editions have no row in the bundled `resources` table, so
        // there is no meaningful integer id. Nothing may key on it — the reader
        // addresses editions by slug throughout.
        id: -1,
        slug: slug,
        languageCode: languageCode,
        name: name,
        nativeName: nativeName,
        author: author,
        direction: direction,
        sortOrder: sortOrder,
        license: license,
        sourceUrl: sourceUrl,
      );

  @override
  List<Object?> get props => [slug, sha256, installedAt];
}
