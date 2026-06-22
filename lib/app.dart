import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/navigation/route_observer.dart';
import 'core/scroll/quran_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/navigation/presentation/pages/home_page.dart';

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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: GetIt.I<ThemeCubit>(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          return MaterialApp(
            title: 'Al Quran',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            scrollBehavior: const QuranScrollBehavior(),
            navigatorObservers: [routeObserver],
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
