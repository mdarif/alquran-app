import 'package:flutter/material.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/prayer.dart';

String formatPrayerTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

/// The all-five-prayers sheet shown when the indicator is tapped. Lean: just the
/// schedule, with the next prayer highlighted (the prayer names disambiguate
/// AM/PM, so no clutter).
class PrayerTimesSheet extends StatelessWidget {
  const PrayerTimesSheet({required this.times, required this.next, super.key});

  final DailyPrayerTimes times;
  final Prayer? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      key: WidgetKeys.prayerTimesSheet,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prayer times', style: theme.textTheme.titleMedium),
            if (times.location.label != null) ...[
              const SizedBox(height: 2),
              Text(
                times.location.label!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            for (final (prayer, time) in times.schedule)
              _PrayerRow(
                prayer: prayer,
                time: time,
                isNext: prayer == next,
              ),
          ],
        ),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isNext,
  });

  final Prayer prayer;
  final DateTime time;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = isNext ? cs.onPrimaryContainer : cs.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            prayer.label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: fg,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            formatPrayerTime(time),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: fg,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
