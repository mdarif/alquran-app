import 'entities/ayah.dart';
import 'entities/translation_resource.dart';

/// Human-readable language name for a translation's language code.
String languageName(String code) => switch (code) {
      'ur' => 'Urdu',
      'en' => 'English',
      'hi' => 'Hindi',
      _ => code.toUpperCase(),
    };

/// Builds clean, shareable/copyable text for a single ayah: the Arabic, each
/// available translation, and a reference like "Al-Baqarah 2:1".
String buildAyahShareText({
  required Ayah ayah,
  required List<TranslationResource> resources,
  String? surahName,
}) {
  final reference = surahName == null
      ? '${ayah.surahId}:${ayah.ayahNumber}'
      : '$surahName ${ayah.surahId}:${ayah.ayahNumber}';

  final parts = <String>[ayah.textArabic];
  for (final r in resources) {
    final text = ayah.translations[r.id];
    if (text != null) parts.add(text);
  }
  parts.add('— $reference');
  return parts.join('\n\n');
}
