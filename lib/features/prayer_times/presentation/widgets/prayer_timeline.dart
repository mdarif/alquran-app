import 'package:flutter/material.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/prayer.dart';

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
    this.next,
    super.key,
  });

  final DailyPrayerTimes times;
  final DateTime now;
  final Prayer? next;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inactiveColor = scheme.primary.withValues(alpha: 0.14);
    final selected = times.currentSalahAt(now)?.$1 ??
        (next?.isSalah == true ? next : times.nextSalahAfter(now)?.$1);
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
              color: inactiveColor,
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
                        width: entry.$1 == selected ? 26 : 18,
                        height: entry.$1 == selected ? 26 : 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.$1 == selected
                              ? scheme.primary
                              : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        entry.$1.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: entry.$1 == selected
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
    final entries = [
      ('Suhur End', times.suhurEnd),
      ('Iftar', times.iftar),
      ('Tahajjud', _validTahajjudStart()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across is the intended shape, but each card then gets under a
        // third of the width: at a large text scale or on a narrow phone the
        // labels would clip to "Suhur En…". Stack instead of clipping.
        final scaled = MediaQuery.textScalerOf(context).scale(14);
        if (constraints.maxWidth < _stackBelowWidth ||
            scaled > _stackAboveTextSize) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0) const SizedBox(height: _cardGap),
                _card(context, entry.$1, entry.$2, stacked: true),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0) const SizedBox(width: _cardGap),
                Expanded(child: _card(context, entry.$1, entry.$2)),
              ],
            ],
          ),
        );
      },
    );
  }

  DateTime? _validTahajjudStart() {
    final explicit = nextFajr;
    final fajr = explicit != null && explicit.isAfter(times.maghrib)
        ? explicit
        : times.fajr.add(const Duration(days: 1));
    if (!fajr.isAfter(times.maghrib)) return null;
    return times.lastThirdFrom(fajr);
  }

  /// One timing as its own card. Stacked, the label and time sit on a single
  /// line — a full-width card with two centred lines reads as a gap, not a card.
  Widget _card(
    BuildContext context,
    String label,
    DateTime? time, {
    bool stacked = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelText = Text(
      label,
      maxLines: 2,
      style: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSecondaryContainer.withValues(alpha: 0.78),
        fontWeight: FontWeight.w500,
      ),
    );
    // scaleDown rather than an overflow marker: a clipped or ellipsised clock
    // time is unreadable, a slightly smaller one is not.
    final timeText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        time == null ? '-' : formatClockTime(time, use24h: _use24h(context)),
        maxLines: 1,
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
      ),
      child: stacked
          ? Row(
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 12),
                timeText,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                labelText,
                const SizedBox(height: 4),
                timeText,
              ],
            ),
    );
  }

  bool _use24h(BuildContext context) =>
      MediaQuery.alwaysUse24HourFormatOf(context);
}

/// Below this width each of the three cards gets under ~110 logical px, which
/// is not enough for "Suhur End" over a 12-hour clock time.
const double _stackBelowWidth = 330;

/// `labelMedium` is 12sp and the cards are laid out for roughly the default
/// scale; past this the three-across form stops fitting whatever the width.
const double _stackAboveTextSize = 19;

/// House 8/12/16 spacing — matches the gap between the timeline and this row.
const double _cardGap = 8;
