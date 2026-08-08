import 'package:al_quran/core/app_update_config.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/core/theme/theme_cubit.dart';
import 'package:al_quran/core/theme/theme_toggle_button.dart';
import 'package:al_quran/features/about/presentation/pages/about_page.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_check_result.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_prompt.dart';
import 'package:al_quran/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:al_quran/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:al_quran/features/navigation/presentation/pages/more_page.dart';
import 'package:al_quran/features/navigation/presentation/pages/reminders_settings_page.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeAppUpdateRepository implements AppUpdateRepository {
  _FakeAppUpdateRepository([this.prompt]);

  AppUpdatePrompt? prompt;
  String? error;
  String? dismissedVersion;

  @override
  Future<AppUpdateCheckResult> check({bool ignoreDismissal = false}) async {
    if (error != null) return AppUpdateCheckResult.error(error!);
    final p = prompt;
    return p == null
        ? const AppUpdateCheckResult.upToDate()
        : AppUpdateCheckResult.available(p);
  }

  @override
  Future<void> dismiss(String latestVersion) async {
    dismissedVersion = latestVersion;
  }
}

class _FakePrayerNotificationSettingsRepository
    implements PrayerNotificationSettingsRepository {
  @override
  bool enabled = false;
  @override
  bool get allowZoneMismatchAlerts => false;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
  @override
  Future<void> setAllowZoneMismatchAlerts(bool value) async {}
}

class _FakePrayerTimesRepository implements PrayerTimesRepository {
  @override
  GeoLocation? get location => null;
  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.unavailable, null);

  @override
  Future<void> saveLocation(GeoLocation location) async {}

  @override
  Future<void> clearLocation() async {}
  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) => null;
}

Future<void> _pumpMore(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(const {'theme_choice': 'duha'});
  final theme = ThemeCubit(await SharedPreferences.getInstance());
  final prayerNotifications = PrayerNotificationsCubit(
    _FakePrayerNotificationSettingsRepository(),
    _FakeNotificationSchedulerNoop(),
    _FakePrayerTimesRepository(),
  );
  addTearDown(theme.close);
  addTearDown(prayerNotifications.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: theme),
        BlocProvider<PrayerNotificationsCubit>.value(
          value: prayerNotifications,
        ),
      ],
      child: const MaterialApp(home: MorePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GetIt.I
      ..registerLazySingleton<AyahRepository>(_FakeAyahRepository.new)
      ..registerLazySingleton<ReaderSettingsRepository>(
        _FakeReaderSettingsRepository.new,
      )
      ..registerLazySingleton<AppUpdateRepository>(
        _FakeAppUpdateRepository.new,
      )
      ..registerLazySingleton<AppUpdateCubit>(
        () => AppUpdateCubit(GetIt.I<AppUpdateRepository>()),
      );
  });
  tearDown(GetIt.I.reset);

  testWidgets('lists Reading Theme, Reminders, Settings, and About in order',
      (tester) async {
    await _pumpMore(tester);

    expect(find.byKey(WidgetKeys.morePage), findsOneWidget);
    expect(find.byKey(WidgetKeys.moreReadingThemeRow), findsOneWidget);
    expect(find.text('Reading Theme'), findsOneWidget);
    expect(find.byKey(WidgetKeys.moreRemindersRow), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.byKey(WidgetKeys.moreSettingsRow), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(WidgetKeys.moreAboutRow), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    final themeTop =
        tester.getTopLeft(find.byKey(WidgetKeys.moreReadingThemeRow)).dy;
    final remindersTop =
        tester.getTopLeft(find.byKey(WidgetKeys.moreRemindersRow)).dy;
    final settingsTop =
        tester.getTopLeft(find.byKey(WidgetKeys.moreSettingsRow)).dy;
    final aboutTop = tester.getTopLeft(find.byKey(WidgetKeys.moreAboutRow)).dy;
    expect(themeTop, lessThan(settingsTop));
    expect(themeTop, lessThan(remindersTop));
    expect(remindersTop, lessThan(settingsTop));
    expect(settingsTop, lessThan(aboutTop));
  });

  testWidgets('root menu is fixed, not scrollable', (tester) async {
    await _pumpMore(tester);

    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('tapping Reading Theme opens the Reading Theme sheet',
      (tester) async {
    await _pumpMore(tester);
    await tester.tap(find.byKey(WidgetKeys.moreReadingThemeRow));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingLightSheet), findsOneWidget);
  });

  testWidgets('tapping Reminders opens the Reminders page', (tester) async {
    await _pumpMore(tester);
    await tester.tap(find.byKey(WidgetKeys.moreRemindersRow));
    await tester.pumpAndSettle();

    expect(find.byType(RemindersSettingsPage), findsOneWidget);
  });

  testWidgets('tapping Settings opens Settings', (tester) async {
    await _pumpMore(tester);
    await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.appSettingsPage), findsOneWidget);
  });

  testWidgets('tapping About opens About directly', (tester) async {
    await _pumpMore(tester);
    await tester.tap(find.byKey(WidgetKeys.moreAboutRow));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.aboutPage), findsOneWidget);
  });

  group('Settings (reached via More)', () {
    testWidgets('offers the moved app actions', (tester) async {
      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.shareAppButton), findsOneWidget);
      expect(find.text('Share Al Quran'), findsOneWidget);
      expect(find.byKey(WidgetKeys.appUpdateMenuButton), findsOneWidget);
      expect(find.text('Up to date'), findsOneWidget);
      expect(find.byKey(WidgetKeys.aboutMenuButton), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('highlights when an update is available', (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository(
          AppUpdatePrompt(
            currentVersion: '1.2.1',
            latestVersion: '1.2.2',
            storeUrl: Uri.parse(androidPlayStoreUrl),
            message: 'A new version is available.',
          ),
        ),
      );

      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateMenuButton), findsOneWidget);
      expect(find.text('Update available'), findsWidgets);
    });

    testWidgets('row shows "Couldn\'t check" when offline/unreachable',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository()..error = 'Network request failed',
      );

      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.appUpdateMenuButton), findsOneWidget);
      expect(find.text("Couldn't check"), findsOneWidget);
    });

    testWidgets('manual check shows update details before opening the store',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository(
          AppUpdatePrompt(
            currentVersion: '1.2.2',
            latestVersion: '1.2.6',
            storeUrl: Uri.parse(androidPlayStoreUrl),
            message: 'A new version is available.',
          ),
        ),
      );

      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.appUpdateMenuButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update available'), findsWidgets);
      expect(find.textContaining('Installed: 1.2.2'), findsOneWidget);
      expect(find.textContaining('Latest: 1.2.6'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('Update'), findsWidgets);
    });

    testWidgets('manual check shows an in-app current-version result',
        (tester) async {
      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.appUpdateMenuButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Al Quran is up to date'), findsOneWidget);
      expect(
        find.text('You are already using the latest version.'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('manual check surfaces an in-app result when offline',
        (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository()..error = 'Network request failed',
      );

      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.appUpdateMenuButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Couldn\'t check right now'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Network request failed'), findsNothing);
    });

    testWidgets('shows a required update as non-dismissible', (tester) async {
      await GetIt.I.unregister<AppUpdateRepository>();
      GetIt.I.registerLazySingleton<AppUpdateRepository>(
        () => _FakeAppUpdateRepository(
          AppUpdatePrompt(
            currentVersion: '1.0.0',
            latestVersion: '1.2.2',
            storeUrl: Uri.parse(androidPlayStoreUrl),
            message: 'Please update to continue.',
            required: true,
          ),
        ),
      );

      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.appUpdateMenuButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update required'), findsWidgets);
      expect(find.text('Not now'), findsNothing);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('only shows chevrons for navigation rows', (tester) async {
      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();

      Finder chevronInside(Key key) => find.descendant(
            of: find.byKey(key),
            matching: find.byIcon(AppIcons.chevronRight),
          );

      expect(chevronInside(WidgetKeys.shareAppButton), findsNothing);
      expect(chevronInside(WidgetKeys.appUpdateMenuButton), findsNothing);
      expect(chevronInside(WidgetKeys.aboutMenuButton), findsOneWidget);
    });

    testWidgets('keeps translations out of the app settings surface',
        (tester) async {
      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
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

    testWidgets('opens the About screen (nested, via Settings)',
        (tester) async {
      await _pumpMore(tester);
      await tester.tap(find.byKey(WidgetKeys.moreSettingsRow));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(WidgetKeys.aboutMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.aboutMenuButton));
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);
    });
  });
}

/// A no-op [NotificationScheduler] fake — [PrayerNotificationsCubit] only
/// needs it to construct; its methods aren't exercised by these tests.
class _FakeNotificationSchedulerNoop implements NotificationScheduler {
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
