import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
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
import 'package:al_quran/features/reader/presentation/pages/bookmarks_page.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for swapping the reader app-bar's Reading Theme icon
/// for a Bookmarks shortcut (the theme picker moved into Settings instead) —
/// requested after bookmarks shipped and the owner judged them more
/// discoverable-worthy of the scarce app-bar real estate than Reading Theme.
class _Repo implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => [
        Ayah(
          id: 1,
          surahId: target.value,
          ayahNumber: 1,
          textArabic: 'بِسْمِ اللَّهِ',
          translations: const {},
          isSajda: false,
        ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var i = 1; i <= 114; i++)
          i: SurahHeading(number: i, nameEnglish: 'Chapter $i', totalAyahs: 3),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => [];
}

class _Bookmarks implements AyahBookmarkRepository {
  @override
  Set<int> get bookmarkedAyahIds => const {};
  @override
  bool isBookmarked(int ayahId) => false;
  @override
  Future<void> setBookmarked(int ayahId, bool bookmarked) async {}
  @override
  Future<List<Ayah>> bookmarkedAyahs() async => const [];
}

class _LastRead implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null;
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
  Future<void> setSelectedTranslations(List<String> codes) async {}
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

Future<ThemeCubit> _fixedTheme(DayPhase phase) async {
  SharedPreferences.setMockInitialValues({'theme_choice': phase.name});
  final cubit = ThemeCubit(await SharedPreferences.getInstance());
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GetIt.I
      ..registerFactory<ReaderCubit>(() => ReaderCubit(_Repo(), _LastRead()))
      ..registerLazySingleton<ReaderSettingsRepository>(() => _Settings())
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()))
      ..registerLazySingleton<AyahRepository>(() => _Repo())
      ..registerLazySingleton<AyahBookmarkRepository>(() => _Bookmarks());
  });
  tearDown(GetIt.I.reset);

  Future<void> pump(WidgetTester tester, ThemeCubit theme) async {
    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: theme,
        child: const MaterialApp(
          home: ReaderPage(target: ReaderTarget.surah(2, 'Al-Baqarah')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the app bar shows Bookmarks instead of the Reading Theme toggle',
    (tester) async {
      await pump(tester, await _fixedTheme(DayPhase.duha));

      expect(find.byKey(WidgetKeys.readerBookmarksButton), findsOneWidget);
      expect(find.byType(ThemeToggleButton), findsNothing);
    },
  );

  testWidgets('tapping Bookmarks opens the Bookmarks page', (tester) async {
    await pump(tester, await _fixedTheme(DayPhase.duha));

    await tester.tap(find.byKey(WidgetKeys.readerBookmarksButton));
    await tester.pumpAndSettle();

    expect(find.byType(BookmarksPage), findsOneWidget);
  });

  testWidgets(
    'Settings does not duplicate the Home Reading Theme action',
    (tester) async {
      await pump(tester, await _fixedTheme(DayPhase.duha));

      await tester.tap(find.byKey(WidgetKeys.settingsButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.readingThemeMenuButton), findsNothing);
      expect(find.text('Reading Theme'), findsNothing);
    },
  );
}
