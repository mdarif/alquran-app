import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/surahs/presentation/pages/surah_list_page.dart';

class AlQuranApp extends StatelessWidget {
  const AlQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Quran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SurahListPage(),
    );
  }
}
