import 'package:flutter/foundation.dart' show kDebugMode;
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

/// "Today"/"Tomorrow" for the near days (so an event lingering on its own day
/// reads as current), else the short date. Uses the real clock — display only.
String _relativeDate(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return _shortDate(d);
}

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
                  if (state.batteryOptimized) ...[
                    const SizedBox(height: 8),
                    _ReliabilityHint(onFix: cubit.fixReliability),
                  ],
                  if (kDebugMode) _DebugDeliveryPanel(state: state, cubit: cubit),
                  if (state.upcoming.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Up next',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    for (final o in state.upcoming) _Row(occurrence: o),
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
    final relative = _relativeDate(occurrence.eventDate);
    final isToday = relative == 'Today';

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(occurrence.shortLabel, style: theme.textTheme.bodyMedium),
                if (occurrence.hijriLabel != null)
                  Text(
                    occurrence.hijriLabel!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relative,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isToday ? gold : cs.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w600 : null,
            ),
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

/// Shown when the app isn't exempt from battery optimization — the OS may delay
/// or drop reminders. Tapping re-runs the system exemption prompt.
class _ReliabilityHint extends StatelessWidget {
  const _ReliabilityHint({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onFix,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.battery_alert_rounded, size: 18, color: cs.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your phone may delay reminders. Tap to allow background '
                    'activity for reliable delivery.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DEBUG ONLY (`kDebugMode`) — never ships. A live readout of the three things
/// that gate Android scheduled delivery, plus a button that schedules a REAL
/// notification ~2 min out through AlarmManager (an immediate `show` would prove
/// nothing). Lets us verify on-device delivery without waiting for a real event.
class _DebugDeliveryPanel extends StatefulWidget {
  const _DebugDeliveryPanel({required this.state, required this.cubit});

  final RemindersState state;
  final RemindersCubit cubit;

  @override
  State<_DebugDeliveryPanel> createState() => _DebugDeliveryPanelState();
}

class _DebugDeliveryPanelState extends State<_DebugDeliveryPanel> {
  String? _report;

  RemindersState get state => widget.state;
  RemindersCubit get cubit => widget.cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'debug · delivery (kDebugMode)',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.tertiary),
          ),
          const SizedBox(height: 6),
          _statusRow('notifications allowed', state.permissionGranted),
          _statusRow(
            'exact alarms allowed',
            state.exactAlarmsAllowed,
            onFix: cubit.fixExactAlarms,
          ),
          _statusRow(
            'battery exempt',
            !state.batteryOptimized,
            onFix: cubit.fixReliability,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                final report = await cubit.scheduleDeliveryTest();
                debugPrint('[reminders] delivery test: $report');
                if (mounted) setState(() => _report = report);
              },
              icon: const Icon(Icons.schedule_send_outlined, size: 18),
              label: const Text('Schedule test in 2 min'),
            ),
          ),
          if (_report != null) ...[
            const SizedBox(height: 6),
            Text(
              _report!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _report!.startsWith('Scheduled') ? cs.primary : cs.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool ok, {VoidCallback? onFix}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: ok ? Colors.green : cs.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: theme.textTheme.bodySmall),
              ),
              if (!ok && onFix != null)
                GestureDetector(
                  onTap: onFix,
                  child: Text(
                    'tap to fix',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
