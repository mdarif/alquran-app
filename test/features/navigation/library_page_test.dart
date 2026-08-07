import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/navigation/presentation/pages/library_page.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_bookmark_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/presentation/pages/bookmarks_page.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/entities/installed_edition.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:al_quran/features/translations/presentation/cubit/translations_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _FakeBookmarkRepository implements AyahBookmarkRepository {
  @override
  Set<int> get bookmarkedAyahIds => const {};
  @override
  Future<List<Ayah>> bookmarkedAyahs() async => const [];
  @override
  bool isBookmarked(int ayahId) => false;
  @override
  Future<void> setBookmarked(int ayahId, bool bookmarked) async {}
}

class _FakeAyahRepository implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [];
  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {};
  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeTafsirRepository implements TafsirRepository {
  @override
  Future<TafsirCatalogue> catalogue() async => const TafsirCatalogue(
        resources: [
          TafsirCatalogueEntry(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            file: 'en.db.gz',
            bytes: 0,
            sha256: 'sha',
            uncompressedBytes: 0,
            uncompressedSha256: 'raw-sha',
            ayahCount: 6236,
            textGroupCount: 0,
            abridged: true,
          ),
        ],
      );

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async =>
      null;

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<void> remove(String slug) async {}

  @override
  Future<List<TafsirResource>> installed() async => const [];
}

class _FakeEditionRepository implements EditionRepository {
  @override
  Future<EditionCatalogue> catalogue() async =>
      const EditionCatalogue(editions: []);

  @override
  Future<List<InstalledEdition>> installed() async => const [];

  @override
  Future<void> install(
    CatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<void> remove(String slug) async {}
}

Future<void> _pumpLibrary(WidgetTester tester) async {
  GetIt.I
    ..registerLazySingleton<AyahBookmarkRepository>(_FakeBookmarkRepository.new)
    ..registerLazySingleton<AyahRepository>(_FakeAyahRepository.new)
    ..registerLazySingleton<TafsirRepository>(_FakeTafsirRepository.new)
    ..registerLazySingleton<TafsirCubit>(
      () => TafsirCubit(GetIt.I<TafsirRepository>()),
    )
    ..registerLazySingleton<EditionRepository>(_FakeEditionRepository.new)
    ..registerLazySingleton<TranslationsCubit>(
      () => TranslationsCubit(GetIt.I<EditionRepository>(), const []),
    );
  await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(GetIt.I.reset);

  testWidgets('lists Bookmarks, Translations, and Tafsir in that order',
      (tester) async {
    await _pumpLibrary(tester);

    expect(find.byKey(WidgetKeys.libraryPage), findsOneWidget);
    expect(find.byKey(WidgetKeys.libraryBookmarksRow), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.byKey(WidgetKeys.libraryTranslationsRow), findsOneWidget);
    expect(find.text('Translations'), findsOneWidget);
    expect(find.byKey(WidgetKeys.libraryTafsirRow), findsOneWidget);
    expect(find.text('Tafsir'), findsOneWidget);

    final bookmarksTop =
        tester.getTopLeft(find.byKey(WidgetKeys.libraryBookmarksRow)).dy;
    final translationsTop =
        tester.getTopLeft(find.byKey(WidgetKeys.libraryTranslationsRow)).dy;
    final tafsirTop =
        tester.getTopLeft(find.byKey(WidgetKeys.libraryTafsirRow)).dy;
    expect(bookmarksTop, lessThan(translationsTop));
    expect(translationsTop, lessThan(tafsirTop));
  });

  testWidgets('tapping Bookmarks opens the Bookmarks page', (tester) async {
    await _pumpLibrary(tester);

    await tester.tap(find.byKey(WidgetKeys.libraryBookmarksRow));
    await tester.pumpAndSettle();

    expect(find.byType(BookmarksPage), findsOneWidget);
  });

  testWidgets('tapping Tafsir opens the Tafsir sheet', (tester) async {
    await _pumpLibrary(tester);

    await tester.tap(find.byKey(WidgetKeys.libraryTafsirRow));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.tafsirPage), findsOneWidget);
    expect(find.textContaining('Tafsir Ibn Kathir'), findsWidgets);
  });

  testWidgets('missing bookmark repos → a snackbar, not a crash',
      (tester) async {
    // Register only what LibraryPage itself needs to build (Translations/
    // Tafsir cubits) — leave the bookmark repos unregistered.
    GetIt.I
      ..registerLazySingleton<TafsirRepository>(_FakeTafsirRepository.new)
      ..registerLazySingleton<TafsirCubit>(
        () => TafsirCubit(GetIt.I<TafsirRepository>()),
      )
      ..registerLazySingleton<EditionRepository>(_FakeEditionRepository.new)
      ..registerLazySingleton<TranslationsCubit>(
        () => TranslationsCubit(GetIt.I<EditionRepository>(), const []),
      );
    await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.libraryBookmarksRow));
    await tester.pumpAndSettle();

    expect(
      find.text('Restart Al Quran to finish enabling bookmarks'),
      findsOneWidget,
    );
    expect(find.byType(BookmarksPage), findsNothing);
  });
}
