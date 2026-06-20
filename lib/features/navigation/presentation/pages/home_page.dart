import 'package:flutter/material.dart';

import '../../../reader/presentation/widgets/continue_reading_banner.dart';
import '../../../surahs/presentation/pages/surah_list_page.dart';
import '../../domain/entities/index_kind.dart';
import '../widgets/index_list_view.dart';

/// App home: the five-dimensional navigation shell (PRD 4.2) — Surah, Juz, Hizb,
/// Page, Ruku — each a tab over the bundled offline index.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Al Quran'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Surah'),
              Tab(text: 'Page'),
              Tab(text: 'Juz'),
              Tab(text: 'Hizb'),
              Tab(text: 'Ruku'),
            ],
          ),
        ),
        body: const Column(
          children: [
            ContinueReadingBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  SurahListView(),
                  IndexListView(kind: IndexKind.page, label: 'Page'),
                  IndexListView(kind: IndexKind.juz, label: 'Juz'),
                  IndexListView(kind: IndexKind.hizb, label: 'Hizb'),
                  IndexListView(kind: IndexKind.ruku, label: 'Ruku'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
