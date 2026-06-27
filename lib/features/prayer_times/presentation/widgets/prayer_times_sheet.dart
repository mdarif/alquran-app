import 'package:flutter/material.dart';

import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../../reminders/presentation/sunnah_occasion.dart';
import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/forbidden_window.dart';
import '../../domain/entities/prayer.dart';

String formatPrayerTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

/// The all-five-prayers sheet shown when the indicator is tapped. Lean: the
/// Islamic (Urdu) + Gregorian date, then the schedule with the next prayer
/// highlighted (the prayer names disambiguate AM/PM, so no clutter).
class PrayerTimesSheet extends StatelessWidget {
  const PrayerTimesSheet({
    required this.times,
    required this.next,
    this.hijriBaseDate,
    this.gregorianDate,
    super.key,
  });

  final DailyPrayerTimes times;
  final Prayer? next;

  /// Gregorian date to convert to the Hijri (already Maghrib-rolled by the
  /// caller); null hides the date block. The [gregorianDate] (civil, for the line
  /// beneath) defaults to it when omitted.
  final DateTime? hijriBaseDate;
  final DateTime? gregorianDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // The three forbidden windows, keyed by reason so each attaches under the
    // row that bounds it (after-sunrise → Sunrise, zenith → Dhuhr, before-sunset
    // → Maghrib).
    final forbidden = {for (final w in times.forbiddenWindows) w.reason: w};
    return SafeArea(
      key: WidgetKeys.prayerTimesSheet,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Prayer Times', style: theme.textTheme.titleMedium),
                if (times.location.label != null) ...[
                  const Spacer(),
                  Flexible(
                    child: Text(
                      times.location.label!,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
            if (hijriBaseDate != null) ...[
              const SizedBox(height: 6),
              _HijriDateLabel(
                baseDate: hijriBaseDate!,
                gregorianDate: gregorianDate ?? hijriBaseDate!,
              ),
            ],
            const SizedBox(height: 10),
            // Fajr, then Sunrise as a muted marker (end of Fajr / Ishraq — not a
            // salah, so never highlighted), then the remaining four prayers.
            _PrayerRow(
              label: Prayer.fajr.label,
              time: times.fajr,
              isNext: next == Prayer.fajr,
            ),
            _PrayerRow(
              label: 'Sunrise',
              time: times.sunrise,
              isNext: next == Prayer.sunrise,
              muted: true,
              forbidden: forbidden[ForbiddenReason.afterSunrise],
            ),
            for (final (prayer, time) in times.schedule.skip(1))
              _PrayerRow(
                label: prayer.label,
                time: time,
                isNext: prayer == next,
                forbidden: switch (prayer) {
                  Prayer.dhuhr => forbidden[ForbiddenReason.zenith],
                  Prayer.maghrib => forbidden[ForbiddenReason.beforeSunset],
                  _ => null,
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.label,
    required this.time,
    required this.isNext,
    this.muted = false,
    this.forbidden,
  });

  final String label;
  final DateTime time;
  final bool isNext;

  /// A non-salah marker (Sunrise) — dimmed and never highlightable as "next".
  final bool muted;

  /// The forbidden-for-prayer window bounded by this row, if any — rendered as a
  /// small gold caption beneath it.
  final ForbiddenWindow? forbidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = muted ? cs.onSurfaceVariant : cs.onSurface;
    final weight =
        isNext ? FontWeight.w700 : (muted ? FontWeight.w400 : FontWeight.w500);
    final window = forbidden;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isNext
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // A slim accent rail marks the next prayer; the (transparent) bar
              // is reserved on every row so the labels stay aligned.
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: isNext ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 11),
              if (muted) ...[
                AppIcon(AppIcons.sunrise, size: AppIconSize.inline, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontWeight: weight,
                ),
              ),
              const Spacer(),
              Text(
                formatPrayerTime(time),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isNext ? cs.primary : fg,
                  fontWeight: weight,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (window != null) _ForbiddenNote(window: window),
        ],
      ),
    );
  }
}

/// The small gold "no prayer" caption beneath a row that bounds a forbidden
/// window (e.g. just after Sunrise, around Dhuhr, just before Maghrib).
class _ForbiddenNote extends StatelessWidget {
  const _ForbiddenNote({required this.window});

  final ForbiddenWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    return Padding(
      // top: tight; left: 14 (accent rail 3 + 11 gap) so it sits under the label.
      padding: const EdgeInsets.only(top: 2, left: 14),
      child: Row(
        children: [
          AppIcon(AppIcons.forbidden, size: AppIconSize.dense, color: gold),
          const SizedBox(width: 5),
          Text(
            'No prayer · ${formatPrayerTime(window.start)}'
            '–${formatPrayerTime(window.end)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Islamic date for the audience: the Hijri date (e.g. `07 Muharram
/// 1448 AH`) and, after a dot, the civil Gregorian date — kept on one line to
/// stay compact. (Two discrete Texts so each remains findable in tests.)
class _HijriDateLabel extends StatelessWidget {
  const _HijriDateLabel({required this.baseDate, required this.gregorianDate});

  final DateTime baseDate;
  final DateTime gregorianDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hijri = HijriDate.fromGregorian(baseDate);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    // On a Sunnah occasion the Hijri date itself is gilded (gold + bolder).
    final isSunnah = sunnahOccasionName(baseDate) != null;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          hijri.formatted,
          style: theme.textTheme.titleSmall?.copyWith(
            color: isSunnah ? gold : cs.onSurface,
            fontWeight: isSunnah ? FontWeight.w700 : null,
          ),
        ),
        Text('  ·  ', style: muted),
        Flexible(
          child: Text(
            formatGregorianDate(gregorianDate),
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );
  }
}
