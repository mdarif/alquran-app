import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/navigation/route_observer.dart';
import 'core/scroll/quran_scroll_behavior.dart';
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
      // Time may have crossed into a new "Light of Day" phase while backgrounded.
      GetIt.I<ThemeCubit>().refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: GetIt.I<ThemeCubit>(),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Al Quran',
            debugShowCheckedModeBanner: false,
            theme: themeState.palette.toTheme(),
            // A gentle cross-fade as the light changes — the surface "breathes"
            // between phases instead of snapping.
            themeAnimationDuration: const Duration(milliseconds: 700),
            themeAnimationCurve: Curves.easeInOut,
            scrollBehavior: const QuranScrollBehavior(),
            navigatorObservers: [routeObserver],
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
