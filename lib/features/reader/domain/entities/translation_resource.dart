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

  /// Attribution shown in the reader: the translator when known, else the name.
  String get attribution => author?.trim().isNotEmpty == true ? author! : name;

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
      ];
}
