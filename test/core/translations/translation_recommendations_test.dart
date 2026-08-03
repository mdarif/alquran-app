import 'dart:ui';

import 'package:al_quran/core/translations/translation_recommendations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidates = [
    TranslationCandidate(
      slug: 'ur-junagarhi',
      languageCode: 'ur',
      name: 'Urdu',
      defaultOn: true,
    ),
    TranslationCandidate(
      slug: 'ur-roman',
      languageCode: 'ur',
      name: 'Roman Urdu',
    ),
    TranslationCandidate(
      slug: 'hi-ahsanul-kalam',
      languageCode: 'hi',
      name: 'Hindi',
    ),
    TranslationCandidate(
      slug: 'en-sahih',
      languageCode: 'en',
      name: 'English',
    ),
  ];

  test('Hindi devices get Hindi with Roman Urdu nearby', () {
    final defaults = TranslationRecommendations.freshInstallDefaults(
      candidates,
      locales: const [Locale('hi', 'IN')],
    );
    expect(defaults, {'hi-ahsanul-kalam', 'ur-roman'});
  });

  test('Urdu devices get Urdu with Roman Urdu nearby before English', () {
    final ordered = TranslationRecommendations.sortByLanguagePriority(
      candidates,
      languageCode: (c) => c.languageCode,
      slug: (c) => c.slug,
      name: (c) => c.name,
      locales: const [Locale('ur', 'PK')],
    );
    expect(ordered.take(3).map((c) => c.slug), [
      'ur-junagarhi',
      'ur-roman',
      'en-sahih',
    ]);
  });

  test('English India devices lift Hindi and Urdu above generic fallbacks', () {
    final languages = TranslationRecommendations.languageOrder(
      const ['ur', 'en', 'id', 'hi'],
      const [Locale('en', 'IN')],
    );
    expect(languages.take(3), ['en', 'hi', 'ur']);
  });

  test('India and Pakistan filter pills stay regional', () {
    final india = TranslationRecommendations.visibleLanguageFilters(
      const ['id', 'bn', 'ur', 'en', 'hi'],
      const [Locale('hi', 'IN')],
    );
    final pakistan = TranslationRecommendations.visibleLanguageFilters(
      const ['id', 'bn', 'ur', 'en', 'hi'],
      const [Locale('ur', 'PK')],
    );

    expect(india, ['hi', 'ur', 'en']);
    expect(pakistan, ['ur', 'en', 'hi']);
  });
}
