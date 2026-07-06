import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/mushaf_palette.dart' show DayPhase;
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../../reminders/presentation/cubit/reminders_cubit.dart';
import '../../../reminders/presentation/widgets/reminders_sheet.dart';

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

/// The Home app-bar overflow (`⋯`) that gathers the secondary controls the bar
/// used to show as separate icons — Sunnah reminders and the Reading-Light
/// picker — so the bar stays uncrowded next to the title + prayer pill. Each
/// item is gated by its feature flag (passed in by [HomePage]) and reuses the
/// existing sheets. Cubits are read DEFENSIVELY so an isolated pump won't crash.
class HomeOverflowMenu extends StatelessWidget {
  const HomeOverflowMenu({
    required this.showReminders,
    required this.showReadingLight,
    super.key,
  });

  final bool showReminders;
  final bool showReadingLight;

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
    final reminders = showReminders ? _cubit<RemindersCubit>(context) : null;
    final theme = showReadingLight ? _cubit<ThemeCubit>(context) : null;
    if (reminders == null && theme == null) return const SizedBox.shrink();

    // MenuAnchor (not PopupMenuButton) so the menu hugs its content — the popup
    // menu rounds its width up in fixed steps, leaving a blank strip on the right.
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      builder: (context, controller, _) => IconButton(
        key: WidgetKeys.homeOverflowMenu,
        tooltip: 'More',
        icon: const AppIcon(AppIcons.overflow),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        if (reminders != null)
          _MenuItem(
            icon: AppIcons.reminders,
            filled: reminders.state.enabled,
            label: 'Sunnah Reminders',
            onPressed: () => _openReminders(context, reminders),
          ),
        if (theme != null)
          _MenuItem(
            icon: _phaseIcon(theme.activePhase),
            filled: _phaseFilled(theme.activePhase),
            label: 'Reading Light',
            onPressed: () => _openReadingLight(context, theme),
          ),
      ],
    );
  }

  void _openReminders(BuildContext context, RemindersCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider<RemindersCubit>.value(
        value: cubit,
        child: const RemindersSheet(),
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

/// One compact overflow entry — a [MenuItemButton] that hugs its content.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MenuItemButton(
      leadingIcon: AppIcon(
        icon,
        filled: filled,
        size: AppIconSize.action,
        color: cs.onSurfaceVariant,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
