import 'package:flutter/material.dart';

import '../../domain/entities/daily_prayer_times.dart';

/// A clock time needs an AM/PM marker when it appears without a prayer name
/// (notably Tahajjud); prayer rows deliberately keep their shorter format.
String formatClockTime(DateTime value, {required bool use24h}) {
  final minute = value.minute.toString().padLeft(2, '0');
  if (use24h) return '${value.hour.toString().padLeft(2, '0')}:$minute';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

class PrayerTimeline extends StatelessWidget {
  const PrayerTimeline({
    required this.times,
    required this.now,
    super.key,
  });

  final DailyPrayerTimes times;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = times.currentSalahAt(now)?.$1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 13,
            left: 26,
            right: 26,
            child: Divider(
              color: scheme.primary.withValues(alpha: 0.22),
              height: 2,
            ),
          ),
          Row(
            children: [
              for (final entry in times.schedule)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: entry.$1 == active ? 26 : 18,
                        height: entry.$1 == active ? 26 : 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.$1 == active
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        entry.$1.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: entry.$1 == active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _format(entry.$2),
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')}';
  }
}

class ExtraTimings extends StatelessWidget {
  const ExtraTimings({
    required this.times,
    this.nextFajr,
    super.key,
  });

  final DailyPrayerTimes times;
  final DateTime? nextFajr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                _tile(context, 'Suhur', times.suhurEnd),
                _Divider(color: scheme.outlineVariant),
                _tile(context, 'Iftar', times.iftar),
                _Divider(color: scheme.outlineVariant),
                _tile(
                  context,
                  'Tahajjud',
                  nextFajr == null ? null : times.lastThirdFrom(nextFajr!),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, DateTime? time) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            time == null ? '-' : formatClockTime(time, use24h: use24h),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color,
    );
  }
}
