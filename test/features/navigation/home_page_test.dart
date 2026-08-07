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
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
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

class _FakeIndexRepository implements IndexRepository {
  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async => const [];
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

Future<void> _pumpHome(
  WidgetTester tester, {
  bool advancedNavigation = true,
  bool hijriDate = true,
  bool sunnahReminders = true,
  bool lastReadBanner = true,
  bool softUpdateReminder = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        advancedNavigation: advancedNavigation,
        hijriDate: hijriDate,
        sunnahReminders: sunnahReminders,
        lastReadBanner: lastReadBanner,
        softUpdateReminder: softUpdateReminder,
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
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
