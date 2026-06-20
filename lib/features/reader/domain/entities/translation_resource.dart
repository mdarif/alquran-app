import 'package:equatable/equatable.dart';

/// A translation edition (e.g. Urdu — Junagarhi, Hindi — al-Umari).
class TranslationResource extends Equatable {
  const TranslationResource({
    required this.id,
    required this.languageCode,
    required this.name,
  });

  final int id;
  final String languageCode; // ur | hi
  final String name;

  @override
  List<Object?> get props => [id, languageCode, name];
}
