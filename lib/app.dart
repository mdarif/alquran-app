import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/navigation/presentation/pages/home_page.dart';

class AlQuranApp extends StatelessWidget {
  const AlQuranApp({super.key});

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
            navigatorObservers: [routeObserver],
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
