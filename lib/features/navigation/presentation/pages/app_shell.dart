import 'package:flutter/material.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'more_page.dart';
import 'prayer_page.dart';

/// Top-level app shell: a 4-tab bottom navigation bar (Read / Prayer /
/// Library / More) over an [IndexedStack] of each tab's own root page.
///
/// Deliberately a single root [Navigator] — every "deeper" page a tab opens
/// (Settings, About, Bookmarks, the Reader) is still a normal
/// `Navigator.push`, exactly as before this shell existed. It covers the
/// whole shell (bottom bar included) while pushed, and popping returns to
/// the shell showing whichever tab was active — that alone satisfies "back
/// from a nested page returns to that tab root," with no extra back-stack
/// code or nested Navigators.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _openPrayerTab() => setState(() => _selectedIndex = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(onOpenPrayerTab: _openPrayerTab),
          const PrayerPage(),
          const LibraryPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            key: WidgetKeys.bottomNavRead,
            icon: AppIcon(AppIcons.viewReading),
            label: 'Read',
          ),
          NavigationDestination(
            key: WidgetKeys.bottomNavPrayer,
            icon: AppIcon(AppIcons.phaseDuha),
            label: 'Prayer',
          ),
          NavigationDestination(
            key: WidgetKeys.bottomNavLibrary,
            icon: AppIcon(AppIcons.alKahf),
            label: 'Library',
          ),
          NavigationDestination(
            key: WidgetKeys.bottomNavMore,
            icon: AppIcon(AppIcons.more),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
