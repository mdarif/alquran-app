import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/app_update_config.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_prompt.dart';
import 'package:al_quran/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/home_page.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/hijri_date_line.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_bookmark_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/pages/bookmarks_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/last_read_banner.dart';
import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
import 'package:al_quran/features/surahs/presentation/pages/surah_list_page.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSurahRepository implements SurahRepository {
  @override
  Future<List<Surah>> getSurahs() async => const [
        Surah(
          id: 1,
          nameArabic: 'الفاتحة',
          nameEnglish: 'Al-Fatihah',
          totalAyahs: 7,
          revelationPlace: 'makkah',
        ),
      ];
}

class _FakeLastReadRepository implements LastReadRepository {
  @override
  Future<void> save(LastRead value) async {}
  @override
  Future<LastRead?> load() async => null; // banner stays hidden
}

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
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {}
  @override
  Future<void> resetToDefaults() async {
    script = ArabicScript.uthmani;
    fontSize = ReaderSettingsRepository.defaultFontSize;
    detailed = false;
    selectedTranslations = null;
    recitationSpeed = ReaderSettingsRepository.defaultRecitationSpeed;
    showTranslationPeek = false;
    showArabicMatn = true;
  }
}

class _FakeIndexRepository implements IndexRepository {
  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async => const [];
}

class _FakeAppUpdateRepository implements AppUpdateRepository {
  _FakeAppUpdateRepository([this.prompt]);

  AppUpdatePrompt? prompt;
  String? dismissedVersion;

  @override
  Future<AppUpdatePrompt?> check() async => prompt;

  @override
  Future<void> dismiss(String latestVersion) async {
    dismissedVersion = latestVersion;
    prompt = null;
  }
}

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  @override
  bool enabled = false;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _FakePrayerNotificationSettingsRepository
    implements PrayerNotificationSettingsRepository {
  @override
  bool enabled = false;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _FakePrayerTimesRepository implements PrayerTimesRepository {
  @override
  GeoLocation? get location => null;

  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.unavailable, null);

  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) => null;
}

class _FakeTafsirRepository implements TafsirRepository {
  @override
  Future<TafsirCatalogue> catalogue() async => const TafsirCatalogue(
        resources: [
          TafsirCatalogueEntry(
            slug: 'en-ibn-kathir-abridged',
            languageCode: 'en',
            name: 'Tafsir Ibn Kathir',
            file: 'en-ibn-kathir-abridged.db.gz',
            bytes: 0,
            sha256: 'sha256',
            uncompressedBytes: 0,
            uncompressedSha256: 'raw-sha256',
            ayahCount: 6236,
            textGroupCount: 0,
            abridged: true,
          ),
          TafsirCatalogueEntry(
            slug: 'ur-ibn-kathir',
            languageCode: 'ur',
            name: 'Tafsir Ibn Kathir',
            nativeName: 'اردو',
            direction: 'rtl',
            file: 'ur-ibn-kathir.db.gz',
            bytes: 1024 * 1024,
            sha256: 'sha256-ur',
            uncompressedBytes: 4 * 1024 * 1024,
            uncompressedSha256: 'raw-sha256-ur',
            ayahCount: 6236,
            textGroupCount: 0,
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
  Future<List<TafsirResource>> installed() async => const [];
}

class _FakeNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  bool lastScheduleWasExact = true;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<bool> isBatteryOptimizationExempt() async => true;

  @override
  Future<void> requestBatteryOptimizationExemption() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async =>
      null;

  @override
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {}

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<String?> consumeLaunchPayload() async => null;

  @override
  String get salatChannelId => 'salat_notifications_nature_v4';

  @override
  Future<void> openNotificationSettings({String? channelId}) async {}
}

Future<void> _pumpHome(
  WidgetTester tester, {
  bool advancedNavigation = true,
  bool hijriDate = true,
  bool sunnahReminders = true,
  bool lastReadBanner = true,
  bool lightOfDay = true,
  bool softUpdateReminder = true,
}) async {
  // A fixed light (not auto) so there's no Light-of-Day ticker to leak in tests.
  SharedPreferences.setMockInitialValues(const {'theme_choice': 'duha'});
  final theme = ThemeCubit(await SharedPreferences.getInstance());
  final reminders = RemindersCubit(
    _FakeReminderSettingsRepository(),
    _FakeNotificationScheduler(),
  );
  // AppSettingsPage (opened from the ⋯ overflow) requires this cubit whenever
  // FeatureFlags.prayerTimeNotifications is on, same as the real app.dart tree.
  final prayerNotifications = PrayerNotificationsCubit(
    _FakePrayerNotificationSettingsRepository(),
    _FakeNotificationScheduler(),
    _FakePrayerTimesRepository(),
  );
  addTearDown(theme.close);
  addTearDown(reminders.close);
  addTearDown(prayerNotifications.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: theme),
        BlocProvider<RemindersCubit>.value(value: reminders),
        BlocProvider<PrayerNotificationsCubit>.value(
          value: prayerNotifications,
        ),
      ],
      child: MaterialApp(
        home: HomePage(
          advancedNavigation: advancedNavigation,
          hijriDate: hijriDate,
          sunnahReminders: sunnahReminders,
          lastReadBanner: lastReadBanner,
          lightOfDay: lightOfDay,
          softUpdateReminder: softUpdateReminder,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GetIt.I
      ..registerLazySingleton<SurahRepository>(_FakeSurahRepository.new)
      ..registerFactory<SurahListCubit>(
        () => SurahListCubit(GetIt.I<SurahRepository>()),
      )
      ..registerLazySingleton<LastReadRepository>(_FakeLastReadRepository.new)
      ..registerLazySingleton<AyahBookmarkRepository>(
        _FakeBookmarkRepository.new,
      )
      ..registerLazySingleton<AyahRepository>(_FakeAyahRepository.new)
      ..registerLazySingleton<ReaderSettingsRepository>(
        _FakeReaderSettingsRepository.new,
      )
      ..registerLazySingleton<IndexRepository>(_FakeIndexRepository.new)
      ..registerFactory<IndexListCubit>(
        () => IndexListCubit(GetIt.I<IndexRepository>()),
      )
      ..registerLazySingleton<AppUpdateRepository>(
        _FakeAppUpdateRepository.new,
      )
      ..registerLazySingleton<TafsirRepository>(_FakeTafsirRepository.new)
      ..registerLazySingleton<TafsirCubit>(
        () => TafsirCubit(GetIt.I<TafsirRepository>()),
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

    testWidgets('the Jump-to sheet offers Page/Juz/Hizb/Ruku', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(AppIcons.jumpMenu));
      await tester.pumpAndSettle();

      expect(find.text('Page'), findsOneWidget);
      expect(find.text('Juz'), findsOneWidget);
      expect(find.text('Hizb'), findsOneWidget);
      expect(find.text('Ruku'), findsOneWidget);
    });

    testWidgets('tapping a Jump option opens that index page', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(AppIcons.jumpMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juz'));
      await tester.pumpAndSettle();

      // The sheet is gone; the Juz index page is shown with its app-bar title.
      expect(find.widgetWithText(AppBar, 'Juz'), findsOneWidget);
    });

    testWidgets('the title is plain text — no longer a tap target for About',
        (tester) async {
      // About moved into the ⋯ overflow (covered above); the title itself no
      // longer navigates, so tapping it must not open About.
      await _pumpHome(tester);
      await tester.tap(find.text('Al Quran'));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.aboutPage), findsNothing);
    });

    testWidgets('hides the Jump button when advanced nav is off',
        (tester) async {
      await _pumpHome(tester, advancedNavigation: false);
      expect(find.byIcon(AppIcons.jumpMenu), findsNothing);
      expect(find.byType(SurahListBody), findsOneWidget);
    });

    testWidgets('surfaces the flagged features when their flags are on',
        (tester) async {
      await _pumpHome(tester); // all default to on
      expect(find.byType(HijriDateLine), findsOneWidget);
      expect(find.byType(LastReadBanner), findsOneWidget);
      // Secondary controls live behind the app-bar overflow.
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);
    });

    testWidgets('the overflow menu opens Reading Theme (and reveals its items)',
        (tester) async {
      await _pumpHome(tester); // ThemeCubit is provided → Reading Theme shows
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      expect(find.text('Reading Theme'), findsOneWidget);
      await tester.tap(find.text('Reading Theme'));
      await tester.pumpAndSettle();
      // The Reading Theme sheet opened.
      expect(find.byType(ReadingLightSheet), findsOneWidget);
    });

    testWidgets('the overflow opens Settings', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.appSettingsPage), findsOneWidget);
    });

    testWidgets('the overflow opens Bookmarks', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.bookmarksMenuButton));
      await tester.pumpAndSettle();
      expect(find.byType(BookmarksPage), findsOneWidget);
    });

    testWidgets('the overflow opens Reminders directly (a Settings peer)',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      expect(find.text('Reminders'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.remindersButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.remindersPage), findsOneWidget);
      expect(find.text('Sunnah Reminders'), findsOneWidget);
      expect(find.text('Salat Notifications'), findsOneWidget);
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

    testWidgets('Settings offers the moved app actions', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.shareAppButton), findsOneWidget);
      expect(find.text('Share Al Quran'), findsOneWidget);
      // Reminders moved to the overflow as a Settings peer — not in this list.
      expect(find.byKey(WidgetKeys.remindersButton), findsNothing);
      expect(find.byKey(WidgetKeys.appUpdateMenuButton), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);
      expect(find.byKey(WidgetKeys.aboutMenuButton), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('Settings highlights when an update is available',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository(
          AppUpdatePrompt(
            currentVersion: '1.2.1',
            latestVersion: '1.2.2',
            storeUrl: Uri.parse(androidPlayStoreUrl),
            message: 'A newer version is available.',
          ),
        ),
      );

      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateMenuButton), findsOneWidget);
      expect(find.text('Update available'), findsWidgets);
    });

    testWidgets('Settings only shows chevrons for navigation rows',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();

      Finder chevronInside(Key key) => find.descendant(
            of: find.byKey(key),
            matching: find.byIcon(AppIcons.chevronRight),
          );

      expect(chevronInside(WidgetKeys.shareAppButton), findsNothing);
      expect(chevronInside(WidgetKeys.appUpdateMenuButton), findsNothing);
      expect(chevronInside(WidgetKeys.aboutMenuButton), findsOneWidget);
    });

    testWidgets('Settings keeps translations out of the app settings surface',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();

      final shareTop = tester
          .getTopLeft(
            find.byKey(WidgetKeys.shareAppButton),
          )
          .dy;
      await tester.ensureVisible(find.byKey(WidgetKeys.readerSettingsReset));
      await tester.pumpAndSettle();
      final resetTop = tester
          .getTopLeft(
            find.byKey(WidgetKeys.readerSettingsReset),
          )
          .dy;

      expect(find.widgetWithText(ListTile, 'Translations'), findsNothing);
      expect(find.byKey(WidgetKeys.readingThemeMenuButton), findsNothing);
      expect(find.text('Reading Settings'), findsOneWidget);
      expect(find.text('Reset Reading Settings'), findsOneWidget);
      expect(resetTop, greaterThan(shareTop));
    });

    testWidgets('Settings opens the About screen', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.homeSettingsMenuButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(WidgetKeys.aboutMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.aboutMenuButton));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.aboutPage), findsOneWidget);
    });

    testWidgets(
        'the home overflow exposes Translations and Tafsir before Bookmarks',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.translationsMenuButton), findsOneWidget);
      expect(find.text('Translations'), findsOneWidget);
      expect(find.byKey(WidgetKeys.tafsirMenuButton), findsOneWidget);
      expect(find.text('Tafsir'), findsOneWidget);
      expect(find.byKey(WidgetKeys.bookmarksMenuButton), findsOneWidget);

      final translationsTop = tester
          .getTopLeft(
            find.byKey(WidgetKeys.translationsMenuButton),
          )
          .dy;
      final tafsirTop = tester
          .getTopLeft(
            find.byKey(WidgetKeys.tafsirMenuButton),
          )
          .dy;
      final bookmarksTop = tester
          .getTopLeft(
            find.byKey(WidgetKeys.bookmarksMenuButton),
          )
          .dy;
      expect(translationsTop, lessThan(tafsirTop));
      expect(tafsirTop, lessThan(bookmarksTop));
    });

    testWidgets('the home overflow opens the Tafsir sheet', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.tafsirMenuButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.tafsirPage), findsOneWidget);
      expect(find.byKey(WidgetKeys.tafsirSearchField), findsOneWidget);
      expect(
        find.byKey(WidgetKeys.tafsirLanguageFilter('all')),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKeys.tafsirLanguageFilter('ur')),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKeys.tafsirLanguageFilter('en')),
        findsOneWidget,
      );
      expect(find.textContaining('Tafsir Ibn Kathir'), findsWidgets);
      expect(find.text('English'), findsWidgets);
      expect(find.text('Urdu'), findsWidgets);
      expect(
        find.byKey(WidgetKeys.tafsirDownload('en-ibn-kathir-abridged')),
        findsOneWidget,
      );
    });

    testWidgets('hides each flagged feature when its flag is off',
        (tester) async {
      await _pumpHome(
        tester,
        hijriDate: false,
        sunnahReminders: false,
        lastReadBanner: false,
        lightOfDay: false,
      );
      expect(find.byType(HijriDateLine), findsNothing);
      expect(find.byType(LastReadBanner), findsNothing);
      // The overflow itself stays — Bookmarks/Share/About are unconditional.
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);
      // The reading list itself is unaffected.
      expect(find.byType(SurahListBody), findsOneWidget);
    });
  });

  group('HomePage — app-bar search', () {
    testWidgets('search icon opens a search field and hides the other controls',
        (tester) async {
      await _pumpHome(tester);
      // Normal bar: title + overflow, no search field yet.
      expect(find.byKey(WidgetKeys.surahSearchField), findsNothing);
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.surahSearchButton));
      await tester.pumpAndSettle();

      // Search mode: field + back arrow show; the title + overflow hide.
      expect(find.byKey(WidgetKeys.surahSearchField), findsOneWidget);
      expect(find.byKey(WidgetKeys.surahSearchBack), findsOneWidget);
      expect(find.text('Al Quran'), findsNothing);
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsNothing);
    });

    testWidgets('typing filters the list; back exits and restores it',
        (tester) async {
      // Two surahs so filtering is observable.
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
      expect(find.byKey(WidgetKeys.homeOverflowMenu), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
    });
  });
}
