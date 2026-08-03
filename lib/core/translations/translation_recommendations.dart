import 'dart:ui';

class TranslationCandidate {
  const TranslationCandidate({
    required this.slug,
    required this.languageCode,
    this.name = '',
    this.nativeName = '',
    this.defaultOn = false,
    this.sortOrder = 0,
  });

  final String slug;
  final String languageCode;
  final String name;
  final String nativeName;
  final bool defaultOn;
  final int sortOrder;
}

class TranslationRecommendations {
  const TranslationRecommendations._();

  static const int _maxFreshInstallDefaults = 2;

  static List<String> languageOrder(
    Iterable<String> codes,
    List<Locale> locales,
  ) {
    final unique = {
      for (final code in codes) _normalizedLanguage(code),
    }.where((code) => code.isNotEmpty).toList();
    unique.sort((a, b) {
      final byPriority = _languageScore(a, locales).compareTo(
        _languageScore(b, locales),
      );
      if (byPriority != 0) return byPriority;
      return _languageLabel(a).compareTo(_languageLabel(b));
    });
    return unique;
  }

  static List<String> visibleLanguageFilters(
    Iterable<String> codes,
    List<Locale> locales,
  ) {
    final ordered = languageOrder(codes, locales);
    final local = _localLanguageSet(locales);
    if (local.isEmpty) return ordered;
    return [
      for (final code in ordered)
        if (local.contains(code)) code,
    ];
  }

  static List<T> sortByLanguagePriority<T>(
    Iterable<T> items, {
    required String Function(T item) languageCode,
    String Function(T item)? slug,
    String Function(T item)? name,
    int Function(T item)? sortOrder,
    required List<Locale> locales,
  }) {
    final out = items.toList();
    out.sort((a, b) {
      final byPriority = _candidateScore(
        languageCode: languageCode(a),
        slug: slug?.call(a) ?? '',
        name: name?.call(a) ?? '',
        locales: locales,
      ).compareTo(
        _candidateScore(
          languageCode: languageCode(b),
          slug: slug?.call(b) ?? '',
          name: name?.call(b) ?? '',
          locales: locales,
        ),
      );
      if (byPriority != 0) return byPriority;
      final bySortOrder = (sortOrder?.call(a) ?? 0).compareTo(
        sortOrder?.call(b) ?? 0,
      );
      if (bySortOrder != 0) return bySortOrder;
      return (name?.call(a) ?? '').compareTo(name?.call(b) ?? '');
    });
    return out;
  }

  static Set<String> freshInstallDefaults(
    Iterable<TranslationCandidate> candidates, {
    required List<Locale> locales,
  }) {
    final ordered = sortByLanguagePriority(
      candidates,
      languageCode: (c) => c.languageCode,
      slug: (c) => c.slug,
      name: (c) => '${c.name} ${c.nativeName}',
      sortOrder: (c) => c.sortOrder,
      locales: locales,
    );
    if (ordered.isEmpty) return {};

    final picked = <String>{};
    final primaryLanguage = _primaryLanguage(locales);
    for (final item in ordered) {
      if (_candidateScore(
            languageCode: item.languageCode,
            slug: item.slug,
            name: '${item.name} ${item.nativeName}',
            locales: locales,
          ) >
          35) {
        break;
      }
      if (primaryLanguage.isNotEmpty ||
          item.defaultOn ||
          _normalizedLanguage(item.languageCode) == 'en') {
        picked.add(item.slug);
      }
      if (picked.length >= _maxFreshInstallDefaults) break;
    }
    if (picked.isNotEmpty) return picked;

    final defaults = {
      for (final c in ordered.where((c) => c.defaultOn)) c.slug,
    };
    if (defaults.isNotEmpty) return defaults;
    return {ordered.first.slug};
  }

  static int _candidateScore({
    required String languageCode,
    required String slug,
    required String name,
    required List<Locale> locales,
  }) {
    final language = _normalizedLanguage(languageCode);
    var score = _languageScore(language, locales);
    final haystack = '$languageCode $slug $name'.toLowerCase();
    final romanUrdu = language == 'ur' &&
        (haystack.contains('roman') ||
            haystack.contains('latn') ||
            haystack.contains('transliteration'));
    if (romanUrdu) {
      final primary = _primaryLanguage(locales);
      if (primary == 'hi') score -= 8;
      if (primary == 'ur') score += 8;
      if (_region(locales) == 'PK' || _region(locales) == 'IN') score -= 5;
    }
    return score;
  }

  static int _languageScore(String language, List<Locale> locales) {
    final primary = _primaryLanguage(locales);
    final region = _region(locales);
    if (language == primary) return 0;

    if (primary == 'hi') {
      if (language == 'ur') return 12;
      if (language == 'en') return 24;
    }
    if (primary == 'ur') {
      if (language == 'en') return 16;
      if (language == 'hi') return 24;
    }
    if (primary == 'en') {
      if (region == 'IN' && language == 'hi') return 12;
      if (region == 'IN' && language == 'ur') return 18;
      if (region == 'PK' && language == 'ur') return 8;
      if (region == 'BD' && language == 'bn') return 8;
      if (region == 'ID' && language == 'id') return 8;
    }

    if (region == 'IN') {
      if (language == 'hi') return 20;
      if (language == 'ur') return 28;
      if (language == 'en') return 34;
    }
    if (region == 'PK') {
      if (language == 'ur') return 14;
      if (language == 'en') return 28;
    }
    if (region == 'BD') {
      if (language == 'bn') return 14;
      if (language == 'en') return 28;
    }
    if (region == 'ID') {
      if (language == 'id') return 14;
      if (language == 'en') return 28;
    }

    if (language == 'en') return 40;
    if (language == 'ur') return 50;
    if (language == 'hi') return 55;
    return 100;
  }

  static String _primaryLanguage(List<Locale> locales) =>
      locales.isEmpty ? '' : _normalizedLanguage(locales.first.languageCode);

  static String _region(List<Locale> locales) =>
      locales.isEmpty ? '' : (locales.first.countryCode ?? '').toUpperCase();

  static Set<String> _localLanguageSet(List<Locale> locales) {
    final primary = _primaryLanguage(locales);
    final region = _region(locales);
    if (primary == 'hi' || region == 'IN') return {'hi', 'ur', 'en'};
    if (primary == 'ur' || region == 'PK') return {'ur', 'en', 'hi'};
    if (region == 'BD') return {'bn', 'en', 'ur'};
    if (region == 'ID') return {'id', 'en'};
    return const {};
  }

  static String _normalizedLanguage(String code) =>
      code.split(RegExp('[-_]')).first.toLowerCase();

  static String _languageLabel(String code) {
    return switch (code) {
      'bn' => 'Bangla',
      'en' => 'English',
      'hi' => 'Hindi',
      'id' => 'Indonesian',
      'ur' => 'Urdu',
      _ => code,
    };
  }
}
