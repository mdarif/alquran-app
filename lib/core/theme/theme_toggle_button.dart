import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mushaf_palette.dart';
import 'theme_cubit.dart';

IconData _phaseIcon(DayPhase phase) => switch (phase) {
      DayPhase.fajr => Icons.wb_twilight_outlined,
      DayPhase.duha => Icons.light_mode_outlined,
      DayPhase.asr => Icons.wb_sunny_outlined,
      DayPhase.maghrib => Icons.wb_twilight,
      DayPhase.isha => Icons.dark_mode_outlined,
    };

/// App-bar entry to the **Light of Day** picker. The icon reflects the current
/// light (dawn → sun → dusk → moon); tapping opens the reading-light sheet.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Depend on Theme so the icon refreshes whenever the surface changes (the
    // cubit drives that change, so its activePhase is already current on rebuild).
    Theme.of(context);
    // Read the cubit defensively: degrade gracefully if it isn't provided (a
    // widget test pumping a screen in isolation), rather than crashing.
    ThemeCubit? cubit;
    try {
      cubit = BlocProvider.of<ThemeCubit>(context);
    } catch (_) {
      cubit = null;
    }
    return IconButton(
      tooltip: 'Reading light',
      icon: Icon(_phaseIcon(cubit?.activePhase ?? DayPhase.duha)),
      onPressed: cubit == null ? null : () => _openSheet(context, cubit!),
    );
  }

  void _openSheet(BuildContext context, ThemeCubit cubit) {
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

/// The "Reading light" picker: choose **Light of Day** (auto) or hold a single
/// phase. Reusable — the app-bar button shows it as a sheet; a settings screen
/// could embed it inline.
class ReadingLightSheet extends StatelessWidget {
  const ReadingLightSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final cubit = context.read<ThemeCubit>();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading light', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Light of Day lets the page follow the rhythm of the day.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // Auto — Light of Day.
                _AutoCard(
                  active: state.auto,
                  currentPhase: state.phase,
                  onTap: cubit.setAuto,
                ),
                const SizedBox(height: 18),
                Text(
                  'Or hold a single light',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final p in MushafPalette.ordered)
                      _Swatch(
                        palette: p,
                        // A swatch is "selected" only when the reader is holding
                        // it (not in auto — auto highlights the Auto card).
                        selected: !state.auto && state.phase == p.phase,
                        onTap: () => cubit.setPhase(p.phase),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AutoCard extends StatelessWidget {
  const _AutoCard({
    required this.active,
    required this.currentPhase,
    required this.onTap,
  });

  final bool active;
  final DayPhase currentPhase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _phaseIcon(currentPhase),
                color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Light of Day',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color:
                                active ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                    ),
                    Text(
                      active
                          ? 'Following the day · now ${currentPhase.label}'
                          : 'Follow the time of day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: active
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (active) Icon(Icons.check_circle, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final MushafPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 56,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            // A miniature of the surface: ink lines + an accent badge.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _miniLine(palette.ink, 22),
                const SizedBox(height: 3),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.accentContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 3),
                _miniLine(palette.ink, 16),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            palette.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _miniLine(Color color, double width) => Container(
        width: width,
        height: 2.5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
