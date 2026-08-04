import 'entities/ayah.dart';
import 'entities/translation_resource.dart';

/// Human-readable language name for a translation's language code.
String languageName(String code) => switch (code) {
      'ur' => 'Urdu',
      'en' => 'English',
      'hi' => 'Hindi',
      _ => code.toUpperCase(),
    };

/// Native-script label for a language code.
///
/// Prefer [TranslationResource.languageLabel], which reads `native_name` from
/// the data pipeline: this hardcoded map cannot know about a language added
/// upstream. Kept as the fallback for callers with no edition to hand.
String nativeLanguageName(String code) => switch (code) {
      'ur' => 'اردو',
      'hi' => 'हिन्दी',
      'en' => 'English',
      _ => code.toUpperCase(),
    };

/// Label for an edition chip in the peek card and the Detailed-view filter.
///
/// The language alone where it has a single edition; language *and* edition
/// name where it has several — otherwise two Hindi translations render as two
/// identical "हिन्दी" chips with no way to tell them apart.
String editionChipLabel(
  TranslationResource r,
  List<TranslationResource> available,
) {
  final siblings =
      available.where((o) => o.languageCode == r.languageCode).length;
  return siblings > 1 ? '${r.languageLabel} · ${r.name}' : r.languageLabel;
}

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
    final text = ayah.translations[r.slug];
    if (text != null) parts.add(text);
  }
  parts.add('— $reference');
  parts.add('Al Quran · alquranreader.com');
  return parts.join('\n\n');
}
