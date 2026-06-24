import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_navigator.dart';
import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../domain/entities/reminder_occurrence.dart';
import '../../domain/scheduling/reminder_payload.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String _shortDate(DateTime d) =>
    '${weekdayName(d).substring(0, 3)} ${d.day} ${_monthAbbr[d.month - 1]}';

/// The Sunnah-reminders control sheet (opened from the app-bar bell — kept OFF
/// Home so it doesn't eat top space). A master switch, a "send a test reminder"
/// action, and the upcoming events. Driven by [RemindersCubit].
class RemindersSheet extends StatelessWidget {
  const RemindersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cubit = context.read<RemindersCubit>();

    return BlocBuilder<RemindersCubit, RemindersState>(
      builder: (context, state) {
        return SafeArea(
          key: WidgetKeys.remindersSheet,
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sunnah Reminders',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: state.enabled,
                      onChanged: (on) => on ? cubit.enable() : cubit.disable(),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: Text(
                    state.enabled && !state.permissionGranted
                        ? 'Allow notifications in Settings to receive reminders.'
                        : 'Gentle nudges for Surah Al-Kahf, the White Days, '
                            'Ashura, Arafah & the 10 days of Dhul Hijjah.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                if (state.enabled && state.permissionGranted) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: WidgetKeys.testReminderButton,
                    onPressed: cubit.sendTestReminder,
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: const Text('Send a test reminder'),
                  ),
                  if (state.upcoming.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Upcoming',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    for (final o in state.upcoming.take(5)) _Row(occurrence: o),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.occurrence});

  final ReminderOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    final isKahf = occurrence.opensAlKahf;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              occurrence.shortLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            _shortDate(occurrence.eventDate),
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (isKahf) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );

    if (!isKahf) return content;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // close the sheet first
        // Same routing path as the notification tap.
        routeFromPayload(openAlKahfPayload);
      },
      child: content,
    );
  }
}
