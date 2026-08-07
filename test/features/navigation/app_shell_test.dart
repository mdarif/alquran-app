import 'package:al_quran/core/app_update_config.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_check_result.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_prompt.dart';
import 'package:al_quran/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:al_quran/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:al_quran/features/navigation/domain/entities/index_entry.dart';
import 'package:al_quran/features/navigation/domain/entities/index_kind.dart';
import 'package:al_quran/features/navigation/domain/repositories/index_repository.dart';
import 'package:al_quran/features/navigation/presentation/cubit/index_list_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/app_shell.dart';
import 'package:al_quran/features/navigation/presentation/pages/library_page.dart';
import 'package:al_quran/features/navigation/presentation/pages/more_page.dart';
import 'package:al_quran/features/navigation/presentation/pages/prayer_page.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
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
import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38);

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
  Future<LastRead?> load() async => null;
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
  Future<void> resetToDefaults() async {}
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
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false}) async {
    final p = prompt;
    if (p == null) return const AppUpdateCheckResult.upToDate();
    final suppressed = !ignoreDismissal &&
        !p.required &&
        dismissedVersion == p.latestVersion;
    return suppressed
        ? const AppUpdateCheckResult.upToDate()
        : AppUpdateCheckResult.available(p);
  }

  @override
  Future<void> dismiss(String latestVersion) async {
    dismissedVersion = latestVersion;
  }
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

class _FakePrayerTimesRepositoryEmpty implements PrayerTimesRepository {
  @override
  GeoLocation? get location => null;
  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.unavailable, null);
  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) => null;
}

class _FakePrayerTimesRepositoryWithLocation implements PrayerTimesRepository {
  @override
  GeoLocation? get location => _loc;
  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.ok, _loc);
  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return DailyPrayerTimes(
      fajr: d.add(const Duration(hours: 5)),
      sunrise: d.add(const Duration(hours: 6, minutes: 30)),
      dhuhr: d.add(const Duration(hours: 12)),
      asr: d.add(const Duration(hours: 15, minutes: 30)),
      maghrib: d.add(const Duration(hours: 18, minutes: 42)),
      isha: d.add(const Duration(hours: 20)),
      location: location,
      date: d,
    );
  }
}

class _FakePrayerNotificationSettingsRepository
    implements PrayerNotificationSettingsRepository {
  @override
  bool enabled = false;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
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

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  @override
  bool enabled = false;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  PrayerTimesRepository? prayerTimesRepository,
  AppUpdateRepository? appUpdateRepository,
}) async {
  SharedPreferences.setMockInitialValues(const {'theme_choice': 'duha'});
  final theme = ThemeCubit(await SharedPreferences.getInstance());
  final reminders = RemindersCubit(
    _FakeReminderSettingsRepository(),
    _FakeNotificationScheduler(),
  );
  final prayerNotifications = PrayerNotificationsCubit(
    _FakePrayerNotificationSettingsRepository(),
    _FakeNotificationScheduler(),
    _FakePrayerTimesRepositoryEmpty(),
  );
  final prayerTimes = PrayerTimesCubit(
    prayerTimesRepository ?? _FakePrayerTimesRepositoryEmpty(),
    clock: () => DateTime(2026, 6, 23, 17),
    autoRefresh: false,
  );
  addTearDown(theme.close);
  addTearDown(reminders.close);
  addTearDown(prayerNotifications.close);
  addTearDown(prayerTimes.close);

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
      () => appUpdateRepository ?? _FakeAppUpdateRepository(),
    )
    ..registerLazySingleton<AppUpdateCubit>(
      () => AppUpdateCubit(GetIt.I<AppUpdateRepository>()),
    )
    ..registerLazySingleton<TafsirRepository>(_FakeTafsirRepository.new)
    ..registerLazySingleton<TafsirCubit>(
      () => TafsirCubit(GetIt.I<TafsirRepository>()),
    )
    ..registerLazySingleton<EditionRepository>(_FakeEditionRepository.new)
    ..registerLazySingleton<TranslationsCubit>(
      () => TranslationsCubit(GetIt.I<EditionRepository>(), const []),
    );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: theme),
        BlocProvider<RemindersCubit>.value(value: reminders),
        BlocProvider<PrayerNotificationsCubit>.value(
          value: prayerNotifications,
        ),
        BlocProvider<PrayerTimesCubit>.value(value: prayerTimes),
      ],
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(GetIt.I.reset);

  testWidgets('shows Read initially, with the bottom nav bar', (tester) async {
    await _pumpShell(tester);

    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavRead), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavPrayer), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavLibrary), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavMore), findsOneWidget);
  });

  testWidgets('switches to each tab and preserves the others underneath',
      (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byKey(WidgetKeys.bottomNavPrayer));
    await tester.pumpAndSettle();
    expect(find.byType(PrayerPage), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.bottomNavLibrary));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryPage), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.bottomNavMore));
    await tester.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);

    // IndexedStack keeps every tab mounted — Read's surah list is still
    // there once we switch back, with no reload flash.
    await tester.tap(find.byKey(WidgetKeys.bottomNavRead));
    await tester.pumpAndSettle();
    expect(find.text('Al-Fatihah'), findsOneWidget);
  });

  testWidgets('the Read prayer pill switches to the Prayer tab', (tester) async {
    await _pumpShell(
      tester,
      prayerTimesRepository: _FakePrayerTimesRepositoryWithLocation(),
    );

    expect(find.byKey(WidgetKeys.nextPrayerPill), findsOneWidget);
    await tester.tap(find.byKey(WidgetKeys.nextPrayerPill));
    await tester.pumpAndSettle();

    // On the Prayer tab itself now (not a modal — PrayerTimesSheet renders
    // inline there too, so its key alone can't distinguish the two; the tab
    // body + bottom nav still showing is the real signal).
    expect(find.byType(PrayerPage), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavPrayer), findsOneWidget);
  });

  testWidgets('pushing a page from a tab covers the shell; back returns to '
      'that tab', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byKey(WidgetKeys.bottomNavMore));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.appSettingsPage), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavRead), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.morePage), findsOneWidget);
    expect(find.byKey(WidgetKeys.bottomNavMore), findsOneWidget);
  });

  testWidgets(
      'Home and Settings share one update check — Settings sees what Home '
      'already found', (tester) async {
    final updates = _FakeAppUpdateRepository(
      AppUpdatePrompt(
        currentVersion: '1.2.1',
        latestVersion: '1.2.2',
        storeUrl: Uri.parse(androidPlayStoreUrl),
        message: 'A new version is available.',
      ),
    );

    await _pumpShell(tester, appUpdateRepository: updates);
    expect(find.byKey(WidgetKeys.appUpdateBanner), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.appUpdateLaterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.appUpdateBanner), findsNothing);

    await tester.tap(find.byKey(WidgetKeys.bottomNavMore));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
    await tester.pumpAndSettle();

    // Settings' own open-time check already ran against the (dismissed)
    // repo state, so the row reflects "up to date" — not a blind button.
    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets(
      'a manual Settings check always tells the truth, even after '
      'dismissing that exact version on Home', (tester) async {
    final updates = _FakeAppUpdateRepository(
      AppUpdatePrompt(
        currentVersion: '1.2.1',
        latestVersion: '1.2.2',
        storeUrl: Uri.parse(androidPlayStoreUrl),
        message: 'A new version is available.',
      ),
    );

    await _pumpShell(tester, appUpdateRepository: updates);
    expect(find.byKey(WidgetKeys.appUpdateBanner), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.appUpdateLaterButton));
    await tester.pumpAndSettle();
    expect(updates.dismissedVersion, '1.2.2');

    await tester.tap(find.byKey(WidgetKeys.bottomNavMore));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.appUpdateMenuButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Update available'), findsWidgets);
    expect(find.text('Al Quran is up to date'), findsNothing);
  });
}
