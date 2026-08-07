import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_navigator.dart';
import 'core/feature_flags.dart';
import 'core/home_widget/widget_publisher.dart';
import 'core/navigation/route_observer.dart';
import 'core/scroll/quran_scroll_behavior.dart';
import 'core/theme/mushaf_palette.dart';
import 'core/theme/theme_cubit.dart';
import 'core/warmup/reader_warmup.dart';
import 'features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'features/navigation/presentation/pages/app_shell.dart';
import 'features/reminders/domain/scheduling/notification_scheduler.dart';
import 'features/reminders/presentation/cubit/reminders_cubit.dart';
import 'features/translations/presentation/cubit/translations_cubit.dart';

class AlQuranApp extends StatefulWidget {
  const AlQuranApp({super.key});

  @override
  State<AlQuranApp> createState() => _AlQuranAppState();
}

class _AlQuranAppState extends State<AlQuranApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen awake while the app is open — long-form reading/recitation
    // shouldn't be interrupted by the display dimming or locking.
    unawaited(WakelockPlus.enable());
    // Refresh the home-screen widget with the current schedule on launch.
    if (FeatureFlags.homeScreenWidgets) {
      unawaited(GetIt.I<WidgetPublisher>().publish());
    }
    if (FeatureFlags.sunnahReminders) {
      // (Re)schedule the Sunnah-reminder rolling window on launch.
      unawaited(GetIt.I<RemindersCubit>().refresh());
      // If a tapped reminder cold-launched the app, route it after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final payload =
            await GetIt.I<NotificationScheduler>().consumeLaunchPayload();
        await routeFromPayload(payload);
      });
    }
    if (FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications) {
      unawaited(GetIt.I<PrayerNotificationsCubit>().refresh());
    }
    if (FeatureFlags.proactiveTranslationSync) {
      // Best-effort: fetches the CDN catalogue so a newly published edition
      // (and the Home overflow's "new edition" dot) is up to date without the
      // reader having to open the Translations screen first.
      unawaited(GetIt.I<TranslationsCubit>().load());
    }
    // Prime the reader's caches shortly after the first frame — off the launch
    // critical path (the TOC loads first), so "Continue reading" and the first
    // surah open resolve from memory with no loading flash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 600),
        () => unawaited(warmReaderCache()),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hold the wakelock only while foregrounded — a good battery citizen:
    // re-enable on resume, release when paused/hidden.
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      // Time may have crossed a prayer / "Light of Day" phase while backgrounded.
      if (FeatureFlags.prayerTimes) {
        GetIt.I<PrayerTimesCubit>().refresh();
      }
      GetIt.I<ThemeCubit>().refresh();
      // Keep the home-screen widget in step (new day → new schedule).
      if (FeatureFlags.homeScreenWidgets) {
        unawaited(GetIt.I<WidgetPublisher>().publish());
      }
      // Roll the reminder window forward (new day/month → new Hijri events).
      if (FeatureFlags.sunnahReminders) {
        unawaited(GetIt.I<RemindersCubit>().refresh());
      }
      if (FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications) {
        unawaited(GetIt.I<PrayerNotificationsCubit>().refresh());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: GetIt.I<ThemeCubit>()),
        BlocProvider<PrayerTimesCubit>.value(
          value: GetIt.I<PrayerTimesCubit>(),
        ),
        BlocProvider<RemindersCubit>.value(
          value: GetIt.I<RemindersCubit>(),
        ),
        if (FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications)
          BlocProvider<PrayerNotificationsCubit>.value(
            value: GetIt.I<PrayerNotificationsCubit>(),
          ),
        BlocProvider<TranslationsCubit>.value(
          value: GetIt.I<TranslationsCubit>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          // Light of Day drives the adaptive surface; gated off, hold one static
          // light (the bright-day paper) so the page never shifts.
          final palette = FeatureFlags.lightOfDay
              ? themeState.palette
              : MushafPalette.of(DayPhase.duha);
          return MaterialApp(
            title: 'Al Quran',
            debugShowCheckedModeBanner: false,
            // Global key so a tapped reminder can route from outside the tree.
            navigatorKey: navigatorKey,
            theme: palette.toTheme(),
            // A gentle cross-fade as the light changes — the surface "breathes"
            // between phases instead of snapping.
            themeAnimationDuration: const Duration(milliseconds: 700),
            themeAnimationCurve: Curves.easeInOut,
            scrollBehavior: const QuranScrollBehavior(),
            navigatorObservers: [routeObserver],
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
