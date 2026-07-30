import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_icons.dart';
import 'mushaf_palette.dart';
import 'theme_cubit.dart';

IconData _phaseIcon(DayPhase phase) => switch (phase) {
      DayPhase.fajr => AppIcons.phaseFajr,
      DayPhase.duha => AppIcons.phaseDuha,
      DayPhase.asr => AppIcons.phaseAsr,
      DayPhase.maghrib => AppIcons.phaseMaghrib,
      DayPhase.isha => AppIcons.phaseIsha,
    };

/// Dusk (Maghrib) is the only phase rendered filled — the golden going-down
/// light, distinct from the rising-dawn twilight it shares a glyph with.
bool _phaseFilled(DayPhase phase) => phase == DayPhase.maghrib;

/// App-bar entry to the reading theme picker. The icon reflects the current
/// theme (dawn → sun → dusk → moon); tapping opens the reading-theme sheet.
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
      tooltip: 'Reading Theme',
      icon: AppIcon(
        _phaseIcon(cubit?.activePhase ?? DayPhase.duha),
        filled: _phaseFilled(cubit?.activePhase ?? DayPhase.duha),
      ),
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

/// The "Reading Theme" picker: follow the time of day or choose a fixed phase.
/// Reusable — the app-bar button shows it as a sheet; a settings screen could
/// embed it inline.
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading Theme', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how the reading page looks while you read.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Auto — Follow Time of Day.
                  _AutoCard(
                    active: state.auto,
                    currentPhase: state.phase,
                    onTap: cubit.setAuto,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choose a fixed theme',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final slotWidth =
                          constraints.maxWidth / MushafPalette.ordered.length;
                      final cardWidth = (slotWidth - 6).clamp(42.0, 50.0);
                      final cardHeight = (cardWidth * 1.24).clamp(52.0, 62.0);
                      return Row(
                        children: [
                          for (final p in MushafPalette.ordered)
                            SizedBox(
                              width: slotWidth,
                              child: _Swatch(
                                palette: p,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight,
                                // A swatch is "selected" only when the reader
                                // is holding it (not in auto).
                                selected: !state.auto && state.phase == p.phase,
                                onTap: () => cubit.setPhase(p.phase),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
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
              AppIcon(
                _phaseIcon(currentPhase),
                filled: _phaseFilled(currentPhase),
                color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow Time of Day',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color:
                                active ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                    ),
                    Text(
                      active
                          ? 'Changes automatically · now ${currentPhase.label}'
                          : 'Changes automatically as the day passes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: active
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (active)
                AppIcon(AppIcons.autoSelected, filled: true, color: cs.primary),
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
    required this.cardWidth,
    required this.cardHeight,
    required this.selected,
    required this.onTap,
  });

  final MushafPalette palette;
  final double cardWidth;
  final double cardHeight;
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
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            // A miniature of the surface: ink lines + an accent badge.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _miniLine(palette.ink, 25),
                const SizedBox(height: 4),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: palette.accentContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                _miniLine(palette.ink, 18),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            palette.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                  height: 1.1,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
