import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/app_update_config.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_check_result.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_prompt.dart';
import 'package:al_quran/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:al_quran/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/home_page.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/hijri_date_line.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/last_read_banner.dart';
import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
import 'package:al_quran/features/surahs/presentation/pages/surah_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Simulates a device with no Play Store / no handler for the URL — every
/// launch attempt reports failure, as the real plugin does in that case.
class _FailingUrlLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}

class _FakeSurahRepository implements SurahRepository {
  @override
  Future<List<Surah>> getSurahs() async => [
        const Surah(
          id: 1,
          nameArabic: 'الفاتحة',
          nameEnglish: 'Al-Fatihah',
          totalAyahs: 7,
          revelationPlace: 'makkah',
        ),
        for (var i = 2; i <= 30; i++)
          Surah(
            id: i,
            nameArabic: 'سورة $i',
            nameEnglish: 'Surah $i',
            totalAyahs: 10 + i,
            revelationPlace: i.isEven ? 'madinah' : 'makkah',
          ),
      ];
}

class _FakeLastReadRepository implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null; // banner stays hidden
}

class _FakeAyahRepository implements AyahRepository {
  final requestedTargets = <ReaderTarget>[];

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    requestedTargets.add(target);
    return [
      Ayah(
        id: switch (target.dimension) {
          ReaderDimension.page => 1000 + target.value,
          ReaderDimension.juz => 2000 + target.value,
          _ => target.value,
        },
        surahId: target.dimension == ReaderDimension.page ? 2 : 1,
        ayahNumber: 1,
        textArabic: '${target.dimension.name}:${target.value}',
        isSajda: false,
        translations: const {},
      ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {
        1: SurahHeading(number: 1, nameEnglish: 'Al-Fatihah', totalAyahs: 7),
        2: SurahHeading(number: 2, nameEnglish: 'Al-Baqarah', totalAyahs: 286),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeReaderSettingsRepository implements ReaderSettingsRepository {
  @override
  ArabicScript script = ArabicScript.uthmani;
  @override
  double fontSize = ReaderSettingsRepository.defaultFontSize;
  @override
  bool detailed = false;
  @override
  List<String>? selectedTranslations;
  @override
  double recitationSpeed = ReaderSettingsRepository.defaultRecitationSpeed;
  @override
  bool showTranslationPeek = false;
  @override
  bool showArabicMatn = true;
  @override
  Future<void> setScript(ArabicScript value) async => script = value;
  @override
  Future<void> setFontSize(double value) async => fontSize = value;
  @override
  Future<void> setDetailed(bool value) async => detailed = value;
  @override
  Future<void> setSelectedTranslations(List<String> slugs) async =>
      selectedTranslations = slugs;
  @override
  Future<void> setRecitationSpeed(double value) async =>
      recitationSpeed = value;
  @override
  Future<void> setShowTranslationPeek(bool value) async =>
      showTranslationPeek = value;
  @override
  Future<void> setShowArabicMatn(bool value) async => showArabicMatn = value;
  @override
  bool translationAudioDuringContinuousPlayback = true;
  @override
  Future<void> setTranslationAudioDuringContinuousPlayback(bool value) async =>
      translationAudioDuringContinuousPlayback = value;
  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
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

class _FakeIndexRepository implements IndexRepository {
  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async => switch (kind) {
        IndexKind.juz => [
            const IndexEntry(
              number: 1,
              startSurahId: 1,
              startAyah: 1,
              startSurahName: 'Al-Fatihah',
            ),
            for (var i = 2; i <= 30; i++)
              IndexEntry(
                number: i,
                startSurahId: 2,
                startAyah: i,
                startSurahName: 'Al-Baqarah',
              ),
          ],
        IndexKind.page => [
            const IndexEntry(
              number: 2,
              startSurahId: 2,
              startAyah: 1,
              startSurahName: 'Al-Baqarah',
            ),
            for (var i = 3; i <= 40; i++)
              IndexEntry(
                number: i,
                startSurahId: 2,
                startAyah: i,
                startSurahName: 'Al-Baqarah',
              ),
          ],
        IndexKind.hizb || IndexKind.ruku => const [],
      };
}

class _FakeAppUpdateRepository implements AppUpdateRepository {
  _FakeAppUpdateRepository([this.prompt]);

  AppUpdatePrompt? prompt;
  String? error;
  String? dismissedVersion;
  bool? lastIgnoreDismissal;
  int checkCount = 0;

  @override
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false}) async {
    lastIgnoreDismissal = ignoreDismissal;
    checkCount += 1;
    if (error != null) return AppUpdateCheckResult.error(error!);
    final p = prompt;
    if (p == null) return const AppUpdateCheckResult.upToDate();
    // Mirror the real repository's dismissal gate, so a test can verify a
    // manual check truly ignores it rather than only checking the flag was
    // passed through.
    final suppressed =
        !ignoreDismissal && !p.required && dismissedVersion == p.latestVersion;
    return suppressed
        ? const AppUpdateCheckResult.upToDate()
        : AppUpdateCheckResult.available(p);
  }

  @override
  Future<void> dismiss(String latestVersion) async {
    dismissedVersion = latestVersion;
  }
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
      description: 'RichText containing "$text"',
    );

Future<void> _pumpHome(
  WidgetTester tester, {
  bool hijriDate = true,
  bool sunnahReminders = true,
  bool lastReadBanner = true,
  bool softUpdateReminder = true,
  ValueChanged<bool>? onChromeCollapsedChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        hijriDate: hijriDate,
        sunnahReminders: sunnahReminders,
        lastReadBanner: lastReadBanner,
        softUpdateReminder: softUpdateReminder,
        onChromeCollapsedChanged: onChromeCollapsedChanged,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FakeAyahRepository ayahs;

  setUp(() {
    ayahs = _FakeAyahRepository();
    GetIt.I
      ..registerLazySingleton<SurahRepository>(_FakeSurahRepository.new)
      ..registerFactory<SurahListCubit>(
        () => SurahListCubit(GetIt.I<SurahRepository>()),
      )
      ..registerLazySingleton<LastReadRepository>(_FakeLastReadRepository.new)
      ..registerLazySingleton<AyahRepository>(() => ayahs)
      ..registerLazySingleton<ReaderSettingsRepository>(
        _FakeReaderSettingsRepository.new,
      )
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()))
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(
          GetIt.I<AyahRepository>(),
          GetIt.I<LastReadRepository>(),
        ),
      )
      ..registerLazySingleton<IndexRepository>(_FakeIndexRepository.new)
      ..registerFactory<IndexListCubit>(
        () => IndexListCubit(GetIt.I<IndexRepository>()),
      )
      ..registerLazySingleton<AppUpdateRepository>(
        _FakeAppUpdateRepository.new,
      )
      ..registerLazySingleton<AppUpdateCubit>(
        () => AppUpdateCubit(GetIt.I<AppUpdateRepository>()),
      );
  });
  tearDown(GetIt.I.reset);

  group('HomePage', () {
    testWidgets('is an immersive surah list with no tab bar', (tester) async {
      await _pumpHome(tester);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(SurahListBody), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });

    testWidgets('shows compact Surah/Juz/Page read mode pills', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Start Reading'), findsNothing);
      expect(find.text('Surah'), findsOneWidget);
      expect(find.text('Juz'), findsOneWidget);
      expect(find.text('Page'), findsOneWidget);
    });

    testWidgets('tapping Juz swaps the Read body in place', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.startReadingJuz));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Juz'), findsNothing);
      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('Al-Fatihah 1:1'), findsOneWidget);
      expect(find.byType(SurahListBody), findsNothing);
    });

    testWidgets('tapping Page swaps the Read body in place', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.startReadingPage));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Page'), findsNothing);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Al-Baqarah 2:1'), findsOneWidget);
      expect(find.byType(SurahListBody), findsNothing);
    });

    testWidgets('switching from Juz to Page reloads the page index',
        (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(WidgetKeys.startReadingJuz));
      await tester.pumpAndSettle();
      expect(find.text('Juz 1'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.startReadingPage));
      await tester.pumpAndSettle();

      expect(find.text('Juz 1'), findsNothing);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Al-Baqarah 2:1'), findsOneWidget);
    });

    testWidgets('tapping an embedded Juz row opens Reader with that target',
        (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(WidgetKeys.startReadingJuz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juz 1'));
      await tester.pumpAndSettle();

      final reader = tester.widget<ReaderPage>(find.byType(ReaderPage));
      expect(reader.target, const ReaderTarget.juz(1));
      expect(ayahs.requestedTargets.first, const ReaderTarget.juz(1));
      expect(_richTextContaining('juz:1'), findsWidgets);
    });

    testWidgets('tapping an embedded Page row opens Reader with that target',
        (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(WidgetKeys.startReadingPage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      final reader = tester.widget<ReaderPage>(find.byType(ReaderPage));
      expect(reader.target, const ReaderTarget.page(2));
      expect(ayahs.requestedTargets.first, const ReaderTarget.page(2));
      expect(_richTextContaining('page:2'), findsWidgets);
    });

    testWidgets('tapping Surah restores the Surah list', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.startReadingJuz));
      await tester.pumpAndSettle();
      expect(find.text('Juz 1'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.startReadingSurah));
      await tester.pumpAndSettle();

      expect(find.byType(SurahListBody), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('Juz 1'), findsNothing);
    });

    testWidgets('the old app-bar Jump icon is no longer shown', (tester) async {
      await _pumpHome(tester);
      expect(find.byIcon(AppIcons.jumpMenu), findsNothing);
    });

    testWidgets('the title is plain text — no longer a tap target for About',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.text('Al Quran'));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.aboutPage), findsNothing);
    });

    testWidgets('surfaces the flagged features when their flags are on',
        (tester) async {
      await _pumpHome(tester); // all default to on
      expect(find.byType(HijriDateLine), findsOneWidget);
      expect(find.byType(LastReadBanner), findsOneWidget);
    });

    testWidgets('Continue Reading appears above read mode pills',
        (tester) async {
      await _pumpHome(tester);
      final bannerY = tester.getTopLeft(find.byType(LastReadBanner)).dy;
      final pillsY =
          tester.getTopLeft(find.byKey(WidgetKeys.startReadingSurah)).dy;
      expect(bannerY, lessThan(pillsY));
    });

    testWidgets('scrolling Surah/Juz/Page collapses and restores Home chrome',
        (tester) async {
      final chromeStates = <bool>[];
      await _pumpHome(tester, onChromeCollapsedChanged: chromeStates.add);

      await tester.drag(find.byType(SurahListBody), const Offset(0, -360));
      await tester.pumpAndSettle();
      expect(chromeStates.last, isTrue);

      await tester.drag(find.byType(SurahListBody), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(chromeStates.last, isFalse);

      await tester.tap(find.byKey(WidgetKeys.startReadingJuz));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Juz 1'), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(chromeStates.last, isTrue);

      await tester.drag(find.text('Juz 6'), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(chromeStates.last, isFalse);

      await tester.tap(find.byKey(WidgetKeys.startReadingPage));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Page 2'), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(chromeStates.last, isTrue);
    });

    testWidgets('shows and dismisses the optional app update reminder',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      final updates = _FakeAppUpdateRepository(
        AppUpdatePrompt(
          currentVersion: '1.2.1',
          latestVersion: '1.2.2',
          storeUrl: Uri.parse(androidPlayStoreUrl),
          message: 'A newer version is available.',
        ),
      );
      GetIt.I.registerLazySingleton<AppUpdateRepository>(() => updates);

      await _pumpHome(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateBanner), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(
        find.text('A newer version is available.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(WidgetKeys.appUpdateLaterButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateBanner), findsNothing);
      expect(updates.dismissedVersion, '1.2.2');
    });

    testWidgets('does not show the update banner when the app is current',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository(),
      );

      await _pumpHome(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateBanner), findsNothing);
    });

    testWidgets(
        'the update banner refreshes when the app resumes from background',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      final updates = _FakeAppUpdateRepository();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(() => updates);

      await _pumpHome(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.appUpdateBanner), findsNothing);
      expect(updates.checkCount, 1);

      // A newer version got published server-side while the app sat
      // backgrounded — simulate the OS resuming the app.
      updates.prompt = AppUpdatePrompt(
        currentVersion: '1.2.1',
        latestVersion: '1.2.2',
        storeUrl: Uri.parse(androidPlayStoreUrl),
        message: 'A new version is available.',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(updates.checkCount, 2);
      expect(find.byKey(WidgetKeys.appUpdateBanner), findsOneWidget);
    });

    testWidgets('a required update banner has no Later button and stays put',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      final updates = _FakeAppUpdateRepository(
        AppUpdatePrompt(
          currentVersion: '1.0.0',
          latestVersion: '1.2.2',
          storeUrl: Uri.parse(androidPlayStoreUrl),
          message: 'A newer version is available.',
          required: true,
        ),
      );
      GetIt.I.registerLazySingleton<AppUpdateRepository>(() => updates);

      await _pumpHome(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateBanner), findsOneWidget);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.byKey(WidgetKeys.appUpdateLaterButton), findsNothing);
    });

    testWidgets(
        'tapping Update shows a copy-link fallback when the Play Store '
        'can\'t be opened', (tester) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FailingUrlLauncher();
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      await GetIt.I.unregister<AppUpdateRepository>();
      final updates = _FakeAppUpdateRepository(
        AppUpdatePrompt(
          currentVersion: '1.2.1',
          latestVersion: '1.2.2',
          storeUrl: Uri.parse(androidPlayStoreUrl),
          message: 'A newer version is available.',
        ),
      );
      GetIt.I.registerLazySingleton<AppUpdateRepository>(() => updates);

      await _pumpHome(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.appUpdateNowButton));
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t open the Play Store'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('hides each flagged feature when its flag is off',
        (tester) async {
      await _pumpHome(
        tester,
        hijriDate: false,
        sunnahReminders: false,
        lastReadBanner: false,
      );
      expect(find.byType(HijriDateLine), findsNothing);
      expect(find.byType(LastReadBanner), findsNothing);
      // The reading list itself is unaffected.
      expect(find.byType(SurahListBody), findsOneWidget);
    });
  });

  group('HomePage — app-bar search', () {
    testWidgets('search icon opens a search field and hides the other controls',
        (tester) async {
      await _pumpHome(tester);
      // Normal bar: title + search icon, no search field yet.
      expect(find.byKey(WidgetKeys.surahSearchField), findsNothing);
      expect(find.byKey(WidgetKeys.surahSearchButton), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.surahSearchButton));
      await tester.pumpAndSettle();

      // Search mode: field + back arrow show; the title hides.
      expect(find.byKey(WidgetKeys.surahSearchField), findsOneWidget);
      expect(find.byKey(WidgetKeys.surahSearchBack), findsOneWidget);
      expect(find.text('Al Quran'), findsNothing);
    });

    testWidgets('typing filters the list; back exits and restores it',
        (tester) async {
      await _pumpHome(tester);
      expect(find.text('Al-Fatihah'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.surahSearchButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(WidgetKeys.surahSearchField), 'fatiha');
      await tester.pumpAndSettle();
      expect(find.text('Al-Fatihah'), findsOneWidget);

      // Back exits search, clears the query, and restores the normal bar.
      await tester.tap(find.byKey(WidgetKeys.surahSearchBack));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.surahSearchField), findsNothing);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });
  });
}
