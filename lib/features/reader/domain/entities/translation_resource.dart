import 'package:equatable/equatable.dart';

/// A text edition — one translation or transliteration (e.g. Urdu Junagarhi,
/// Hindi Ahsanul Kalam).
///
/// [slug] is the stable identity: it is what the reader's saved selection holds
/// and what a downloaded artifact is named by. [id] is a local row number that
/// shifts whenever the data pipeline's source list is reordered, so it must
/// never be persisted or sent anywhere.
///
/// [languageCode] groups editions in the picker; it does NOT identify one.
/// Several editions may share a language.
class TranslationResource extends Equatable {
  const TranslationResource({
    required this.id,
    required this.slug,
    required this.languageCode,
    required this.name,
    this.nativeName,
    this.author,
    this.direction,
    this.sortOrder = 0,
    this.defaultOn = false,
    this.license,
    this.sourceUrl,
    this.creditName,
    this.experimental = false,
  });

  final int id;
  final String slug; // stable id, e.g. "ur-junagarhi"
  final String languageCode; // ur | hi  (grouping only)
  final String name; // edition name, e.g. "Ahsanul Kalam"
  final String? nativeName; // اردو, हिन्दी — the picker's language label
  final String? author; // translator, e.g. "Muhammad Junagarhi"
  final String? direction; // rtl | ltr
  final int sortOrder;
  final bool defaultOn;
  final String? license;
  final String? sourceUrl;

  /// Short one-line display name for the reader credit + picker subtitle.
  /// Null means "use author, else name" — only set upstream when [author] is
  /// a multi-person licensing credit too long to show inline.
  final String? creditName;

  /// True = show the "Experimental" pill (unreviewed/pilot content).
  final bool experimental;

  /// One-line credit shown in the reader and the Translations picker.
  String get displayCredit {
    final credit = creditName?.trim();
    if (credit != null && credit.isNotEmpty) return credit;
    final a = author?.trim();
    if (a != null && a.isNotEmpty) return a;
    return name;
  }

  /// Label for the picker: the language in its own script where we have it.
  String get languageLabel =>
      nativeName?.trim().isNotEmpty == true ? nativeName! : languageCode;

  bool get isRtl => direction == 'rtl';

  @override
  List<Object?> get props => [
        id,
        slug,
        languageCode,
        name,
        nativeName,
        author,
        direction,
        sortOrder,
        defaultOn,
        license,
        sourceUrl,
        creditName,
        experimental,
      ];
}
