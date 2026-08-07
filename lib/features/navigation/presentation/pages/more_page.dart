import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/mushaf_palette.dart' show DayPhase;
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../../about/presentation/pages/about_page.dart';
import 'app_settings_page.dart';

/// Phase → app-bar glyph (mirrors [ThemeToggleButton]'s private mapping); Dusk
/// is the only filled one (the golden going-down light).
IconData _phaseIcon(DayPhase phase) => switch (phase) {
      DayPhase.fajr => AppIcons.phaseFajr,
      DayPhase.duha => AppIcons.phaseDuha,
      DayPhase.asr => AppIcons.phaseAsr,
      DayPhase.maghrib => AppIcons.phaseMaghrib,
      DayPhase.isha => AppIcons.phaseIsha,
    };

bool _phaseFilled(DayPhase phase) => phase == DayPhase.maghrib;

/// The More tab: secondary app utilities and preferences — Reading Theme,
/// Settings (which itself carries Share/Check-for-updates), and About. Reuses
/// existing sheets/pages; no new business logic.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static T? _cubit<T extends StateStreamableSource<Object?>>(
    BuildContext context,
  ) {
    try {
      return BlocProvider.of<T>(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        FeatureFlags.lightOfDay ? _cubit<ThemeCubit>(context) : null;
    return Scaffold(
      key: WidgetKeys.morePage,
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (theme != null)
              ListTile(
                key: WidgetKeys.moreReadingThemeRow,
                leading: AppIcon(
                  _phaseIcon(theme.activePhase),
                  filled: _phaseFilled(theme.activePhase),
                ),
                title: const Text('Reading Theme'),
                trailing: const AppIcon(AppIcons.chevronRight),
                onTap: () => _openReadingLight(context, theme),
              ),
            ListTile(
              key: WidgetKeys.moreSettingsRow,
              leading: const AppIcon(AppIcons.settings),
              title: const Text('Settings'),
              trailing: const AppIcon(AppIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AppSettingsPage()),
              ),
            ),
            ListTile(
              key: WidgetKeys.moreAboutRow,
              leading: const AppIcon(AppIcons.about),
              title: const Text('About'),
              trailing: const AppIcon(AppIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReadingLight(BuildContext context, ThemeCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: const ReadingLightSheet(),
      ),
    );
  }
}
