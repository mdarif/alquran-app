import 'package:flutter/material.dart';

import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/pages/home_page.dart';

class AlQuranApp extends StatelessWidget {
  const AlQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Quran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [routeObserver],
      home: const HomePage(),
    );
  }
}
