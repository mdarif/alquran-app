import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_navigator.dart';
import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../domain/entities/reminder_occurrence.dart';
import '../../domain/entities/sunnah_event.dart';
import '../../domain/scheduling/reminder_payload.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String _shortDate(DateTime d) =>
    '${weekdayName(d).substring(0, 3)} ${d.day} ${_monthAbbr[d.month - 1]}';

/// The Home "Upcoming Sunnah Reminders" section. Reads [RemindersCubit]
/// DEFENSIVELY (like the prayer pill) so a screen pumped without it renders
/// nothing. Disabled → an "Enable" card; enabled → the next few events (Al-Kahf
/// opens Surah 18). Modelled on `LastReadBanner`'s card grammar.
class UpcomingRemindersSection extends StatelessWidget {
  const UpcomingRemindersSection({super.key});

  @override
  Widget build(BuildContext context) {
    RemindersCubit? cubit;
    try {
      cubit = BlocProvider.of<RemindersCubit>(context);
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();

    final bloc = cubit;
    return BlocBuilder<RemindersCubit, RemindersState>(
      bloc: bloc,
      builder: (context, state) {
        if (!state.enabled) {
          return _EnableCard(onEnable: bloc.enable);
        }
        if (!state.permissionGranted) {
          return _EnableCard(onEnable: bloc.enable, permissionDenied: true);
        }
        if (state.upcoming.isEmpty) return const SizedBox.shrink();
        return _ListCard(upcoming: state.upcoming, onDisable: bloc.disable);
      },
    );
  }
}

class _EnableCard extends StatelessWidget {
  const _EnableCard({required this.onEnable, this.permissionDenied = false});

  final Future<void> Function() onEnable;
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Material(
        key: WidgetKeys.enableRemindersCard,
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEnable,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunnah Reminders',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        permissionDenied
                            ? 'Allow notifications to get gentle nudges.'
                            : 'Gentle nudges for Al-Kahf, the White Days, '
                                'Ashura & more.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Enable',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.upcoming, required this.onDisable});

  final List<ReminderOccurrence> upcoming;
  final Future<void> Function() onDisable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Material(
        key: WidgetKeys.upcomingRemindersSection,
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming Sunnah Reminders',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (_) => onDisable(),
                  ),
                ],
              ),
              for (final o in upcoming.take(3)) _Row(occurrence: o, gold: gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.occurrence, required this.gold});

  final ReminderOccurrence occurrence;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isKahf = occurrence.kind == SunnahKind.alKahf;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Row(
        children: [
          if (isKahf)
            Icon(Icons.menu_book_rounded, size: 18, color: cs.primary)
          else
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              occurrence.kind.shortLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            _shortDate(occurrence.eventDate),
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (isKahf) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );

    if (!isKahf) return content;
    // Same single routing path as the notification tap (opens Surah 18).
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => routeFromPayload(openAlKahfPayload),
      child: content,
    );
  }
}
