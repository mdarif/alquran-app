import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_bookmark_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/translations/domain/entities/catalogue_entry.dart';
import 'package:al_quran/features/translations/domain/entities/installed_edition.dart';
import 'package:al_quran/features/translations/domain/repositories/edition_repository.dart';
import 'package:al_quran/features/translations/presentation/cubit/translations_cubit.dart';
import 'package:al_quran/features/translations/presentation/pages/translations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// The Settings screen used to be a bottom sheet, so its "Translations" row
/// popped it before opening the Translations sheet — avoiding two stacked
/// sheets. Settings is now a full page; that same pop closed the whole
/// Settings screen the instant Translations was dismissed, not just
/// Translations. This pins the fix: closing Translations must return to
/// Settings, not the reader underneath it.
class _Repo implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => [
        Ayah(
          id: 1,
          surahId: target.value,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          translations: const {'ur-test': 'ترجمہ'},
        ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var i = 1; i <= 114; i++)
          i: SurahHeading(number: i, nameEnglish: 'Chapter $i', totalAyahs: 1),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [
        TranslationResource(
          id: 1,
          slug: 'ur-test',
          languageCode: 'ur',
          name: 'Urdu',
          defaultOn: true,
        ),
      ];
}

class _LastRead implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null;
}

class _Bookmarks implements AyahBookmarkRepository {
  final Set<int> _ids = {};

  @override
  Set<int> get bookmarkedAyahIds => {..._ids};

  @override
  bool isBookmarked(int ayahId) => _ids.contains(ayahId);

  @override
  Future<void> setBookmarked(int ayahId, bool bookmarked) async {
    if (bookmarked) {
      _ids.add(ayahId);
    } else {
      _ids.remove(ayahId);
    }
  }

  @override
  Future<List<Ayah>> bookmarkedAyahs() async => const [];
}

class _Settings implements ReaderSettingsRepository {
  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
  @override
  ArabicScript get script => ArabicScript.uthmani;
  @override
  Future<void> setScript(ArabicScript value) async {}
  @override
  double fontSize = 28;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations;
  @override
  Future<void> setFontSize(double value) async {}
  @override
  Future<void> setDetailed(bool value) async {}
  @override
  Future<void> setSelectedTranslations(List<String> slugs) async =>
      selectedTranslations = slugs;
  @override
  double recitationSpeed = 1.0;
  @override
  Future<void> setRecitationSpeed(double value) async {}
  @override
  bool showTranslationPeek = false;
  @override
  Future<void> setShowTranslationPeek(bool value) async {}
  @override
  bool showArabicMatn = true;
  @override
  Future<void> setShowArabicMatn(bool value) async {}
  @override
  Future<void> resetToDefaults() async {}
}

class _FakeEditionRepo implements EditionRepository {
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

class _SilentPlayer implements AyahRecitationPlayer {
  @override
  Stream<RecitationPlayback> get playbackStream =>
      const Stream<RecitationPlayback>.empty();
  @override
  Future<void> play(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Stream<PlaybackProgress> get progressStream =>
      const Stream<PlaybackProgress>.empty();
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  double get speed => 1.0;
  @override
  Future<void> setLoopMode(RecitationLoop mode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() {
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(_Repo(), _LastRead()))
      ..registerLazySingleton<AyahBookmarkRepository>(_Bookmarks.new)
      ..registerLazySingleton<ReaderSettingsRepository>(_Settings.new)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()))
      ..registerLazySingleton<EditionRepository>(_FakeEditionRepo.new)
      ..registerLazySingleton<TranslationsCubit>(
        () => TranslationsCubit(GetIt.I<EditionRepository>(), const []),
      );
  });
  tearDown(GetIt.I.reset);

  testWidgets('closing Translations returns to Settings, not the reader',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReaderPage(target: ReaderTarget.surah(2, 'S'))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.settingsButton));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.readerSettingsPage), findsOneWidget);

    await tester.tap(find.text('Translations'));
    await tester.pumpAndSettle();
    expect(find.byType(TranslationsPage), findsOneWidget);

    // Dismiss the modal bottom sheet (tap the scrim above it).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(TranslationsPage), findsNothing);
    expect(find.byKey(WidgetKeys.readerSettingsPage), findsOneWidget);
  });

  testWidgets('bookmarking an ayah immediately renders the filled-state action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          target: ReaderTarget.surah(2, 'S'),
          initialDetailed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.ayahBookmarkButton(1)));
    await tester.pumpAndSettle();

    expect(find.text('Bookmark saved'), findsOneWidget);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
  });
}
