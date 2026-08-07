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
  static const double _navIconSize = AppIconSize.action;
  static const double _navHeight = 56;

  int _selectedIndex = 0;
  bool _homeChromeCollapsed = false;

  void _openPrayerTab() => setState(() => _selectedIndex = 1);

  void _setHomeChromeCollapsed(bool collapsed) {
    if (!mounted) return;
    if (_homeChromeCollapsed == collapsed) return;
    setState(() => _homeChromeCollapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            onOpenPrayerTab: _openPrayerTab,
            onChromeCollapsedChanged: _setHomeChromeCollapsed,
          ),
          const PrayerPage(),
          const LibraryPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: _CollapsibleBottomNavigation(
        collapsed: _selectedIndex == 0 && _homeChromeCollapsed,
        height: _navHeight,
        child: DecoratedBox(
          // A hairline top border stands in for the elevation/shadow the flat
          // theme turns off — the same "flat with a crisp edge" language the
          // AppBar and reader dividers already use, instead of a stock M3 tint.
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              height: _navHeight,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  key: WidgetKeys.bottomNavRead,
                  icon: AppIcon(AppIcons.viewReading, size: _navIconSize),
                  label: 'Read',
                ),
                NavigationDestination(
                  key: WidgetKeys.bottomNavPrayer,
                  icon: AppIcon(AppIcons.phaseDuha, size: _navIconSize),
                  label: 'Prayer',
                ),
                NavigationDestination(
                  key: WidgetKeys.bottomNavLibrary,
                  icon: AppIcon(AppIcons.alKahf, size: _navIconSize),
                  label: 'Library',
                ),
                NavigationDestination(
                  key: WidgetKeys.bottomNavMore,
                  icon: AppIcon(AppIcons.more, size: _navIconSize),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsibleBottomNavigation extends StatelessWidget {
  const _CollapsibleBottomNavigation({
    required this.collapsed,
    required this.height,
    required this.child,
  });

  final bool collapsed;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final totalHeight = height + bottomInset;
    return ClipRect(
      child: AnimatedContainer(
        key: WidgetKeys.bottomNavChrome,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        height: collapsed ? 0 : totalHeight,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: totalHeight,
          child: AnimatedSlide(
            offset: collapsed ? const Offset(0, 1) : Offset.zero,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            child: AnimatedOpacity(
              opacity: collapsed ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: SizedBox(height: totalHeight, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
