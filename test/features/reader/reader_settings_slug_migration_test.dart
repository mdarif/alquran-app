import 'package:al_quran/features/reader/data/repositories/reader_settings_repository_impl.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reader's saved selection used to hold LANGUAGE CODES and now holds
/// edition SLUGS. Without a migration a returning reader's choice matches
/// nothing and silently collapses to the default — the app appearing to forget
/// what they had turned on.
void main() {
  const urdu = TranslationResource(
    id: 1,
    slug: 'ur-junagarhi',
    languageCode: 'ur',
    name: 'Junagarhi',
    defaultOn: true,
  );
  const english = TranslationResource(
    id: 2,
    slug: 'en-hilali-khan',
    languageCode: 'en',
    name: 'Hilali & Khan',
  );
  // Two editions of ONE language — the case the whole edition model exists for.
  const hindiA = TranslationResource(
    id: 3,
    slug: 'hi-suhel-farooq-nadwi',
    languageCode: 'hi',
    name: 'Suhel Farooq Khan',
    defaultOn: true,
  );
  const hindiB = TranslationResource(
    id: 4,
    slug: 'hi-ahsanul-kalam',
    languageCode: 'hi',
    name: 'Ahsanul Kalam',
  );
  const all = [urdu, english, hindiA, hindiB];

  const key = 'reader_selected_translations';

  Future<ReaderSettingsRepositoryImpl> repoWith(Object? saved) async {
    SharedPreferences.setMockInitialValues(
      saved == null ? {} : {key: saved},
    );
    return ReaderSettingsRepositoryImpl(await SharedPreferences.getInstance());
  }

  test('language codes become edition slugs, keeping every choice', () async {
    final repo = await repoWith(<String>['ur', 'en']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['ur-junagarhi', 'en-hilali-khan']);
  });

  test('a language with several editions migrates to its default', () async {
    // 'hi' is ambiguous now. We cannot know which the reader meant, so pick the
    // edition marked default rather than the first by id — arbitrary would be
    // worse than deliberate here.
    final repo = await repoWith(<String>['hi']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['hi-suhel-farooq-nadwi']);
  });

  test('a language that is no longer shipped is dropped, not kept', () async {
    final repo = await repoWith(<String>['ur', 'fr']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['ur-junagarhi']);
  });

  test('runs once; a later selection is not clobbered by a second run',
      () async {
    final repo = await repoWith(<String>['ur']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['ur-junagarhi']);

    // The reader then picks the second Hindi edition explicitly.
    await repo.setSelectedTranslations(['hi-ahsanul-kalam']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['hi-ahsanul-kalam']);
  });

  test('slugs already stored survive a migration run', () async {
    // A partially-migrated install, or one written by a newer build.
    final repo = await repoWith(<String>['hi-ahsanul-kalam']);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, ['hi-ahsanul-kalam']);
  });

  test('a fresh install with nothing saved stays unset', () async {
    // null means "never chosen", which the reader resolves to the default
    // edition. Writing an empty list here would be a different state.
    final repo = await repoWith(null);
    await repo.migrateSelectedTranslations(all);
    expect(repo.selectedTranslations, isNull);
  });
}
