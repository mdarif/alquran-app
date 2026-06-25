import 'package:flutter/material.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../../prayer_times/presentation/widgets/hijri_date_line.dart';
import '../../../prayer_times/presentation/widgets/next_prayer_pill.dart';
import '../../../reader/presentation/widgets/last_read_banner.dart';
import '../../../reminders/presentation/widgets/reminders_button.dart';
import '../../../surahs/presentation/pages/surah_list_page.dart';
import '../../domain/entities/index_kind.dart';
import 'index_list_page.dart';

/// App home: an immersive, full-width Surah list with the "continue reading"
/// resume card. Page/Juz/Hizb/Ruku stay out of the way behind a single "Jump to"
/// sheet (gated by [FeatureFlags.advancedNavigation]) so the reader keeps focus.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.advancedNavigation = FeatureFlags.advancedNavigation,
    this.prayerTimes = FeatureFlags.prayerTimes,
  });

  /// Whether to surface Page/Juz/Hizb/Ruku navigation. Injectable for tests.
  final bool advancedNavigation;

  /// Whether to surface the next-prayer pill (and, through it, the times sheet
  /// and location request). Injectable for tests.
  final bool prayerTimes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Al Quran'),
            HijriDateLine(),
          ],
        ),
        actions: [
          if (advancedNavigation)
            IconButton(
              key: WidgetKeys.jumpButton,
              tooltip: 'Jump to (Page · Juz · Hizb · Ruku)',
              icon: const Icon(Icons.format_list_numbered_rounded),
              onPressed: () => _openJumpSheet(context),
            ),
          const RemindersButton(),
          if (prayerTimes) const NextPrayerPill(),
          const ThemeToggleButton(),
        ],
      ),
      body: const Column(
        children: [
          LastReadBanner(),
          Expanded(child: SurahListView()),
        ],
      ),
    );
  }

  void _openJumpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Jump to',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.page,
              label: 'Page',
              icon: Icons.auto_stories_outlined,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.juz,
              label: 'Juz',
              icon: Icons.view_agenda_outlined,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.hizb,
              label: 'Hizb',
              icon: Icons.grid_view_outlined,
            ),
            _JumpTile(
              parentContext: context,
              kind: IndexKind.ruku,
              label: 'Ruku',
              icon: Icons.segment_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({
    required this.parentContext,
    required this.kind,
    required this.label,
    required this.icon,
  });

  /// The page context (not the sheet's) — used to push after the sheet closes.
  final BuildContext parentContext;
  final IndexKind kind;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop(); // close the sheet
        Navigator.of(parentContext).push(
          MaterialPageRoute<void>(
            builder: (_) => IndexListPage(kind: kind, label: label),
          ),
        );
      },
    );
  }
}
