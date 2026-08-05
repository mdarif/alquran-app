import 'package:equatable/equatable.dart';

class TafsirResource extends Equatable {
  const TafsirResource({
    required this.slug,
    required this.languageCode,
    required this.name,
    required this.ayahCount,
    required this.bytes,
    this.nativeName,
    this.author,
    this.direction = 'ltr',
    this.sortOrder = 0,
    this.license,
    this.sourceUrl,
    this.creditName,
    this.abridged = false,
    this.sha256,
    this.installedAt,
  });

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
  final int bytes;
  final String? sha256;
  final DateTime? installedAt;

  String get displayCredit {
    final credit = creditName?.trim();
    if (credit != null && credit.isNotEmpty) return credit;
    final a = author?.trim();
    if (a != null && a.isNotEmpty) return a;
    return name;
  }

  bool get isRtl => direction.toLowerCase() == 'rtl';

  @override
  List<Object?> get props => [
        slug,
        languageCode,
        name,
        nativeName,
        author,
        direction,
        sortOrder,
        license,
        sourceUrl,
        creditName,
        abridged,
        ayahCount,
        bytes,
        sha256,
        installedAt,
      ];
}
