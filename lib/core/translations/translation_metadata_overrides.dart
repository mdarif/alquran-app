class TranslationMetadataOverrides {
  TranslationMetadataOverrides._();

  static const String ahsanulKalamSlug = 'hi-ahsanul-kalam';
  static const Set<String> experimentalSlugs = {ahsanulKalamSlug};

  static String? author(String slug, String? author) {
    if (slug == ahsanulKalamSlug) return 'Muhammad Rais Qureshi Salafi';
    return author;
  }

  static bool isExperimental(String slug) => experimentalSlugs.contains(slug);
}
