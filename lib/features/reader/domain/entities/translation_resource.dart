import 'package:equatable/equatable.dart';

/// A translation edition (e.g. Urdu — Junagarhi, Hindi — al-Umari).
class TranslationResource extends Equatable {
  const TranslationResource({
    required this.id,
    required this.languageCode,
    required this.name,
    this.author,
  });

  final int id;
  final String languageCode; // ur | hi
  final String name; // language label, e.g. "Urdu"
  final String? author; // translator, e.g. "Muhammad Junagarhi"

  /// Attribution shown in the reader: the translator when known, else the name.
  String get attribution => author?.trim().isNotEmpty == true ? author! : name;

  @override
  List<Object?> get props => [id, languageCode, name, author];
}
