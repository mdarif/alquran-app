import 'package:flutter/material.dart';

import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/forbidden_window.dart';
import '../../domain/entities/prayer.dart';

String formatPrayerTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

const List<String> _gregorianMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December', //
];

String formatGregorianDate(DateTime d) =>
    '${d.day} ${_gregorianMonths[d.month - 1]} ${d.year}';

/// The all-five-prayers sheet shown when the indicator is tapped. Lean: the
/// Islamic (Urdu) + Gregorian date, then the schedule with the next prayer
/// highlighted (the prayer names disambiguate AM/PM, so no clutter).
class PrayerTimesSheet extends StatelessWidget {
  const PrayerTimesSheet({
    required this.times,
    required this.next,
    this.hijriBaseDate,
    this.gregorianDate,
    this.hijriAdjustment = 0,
    this.onAdjustHijri,
    super.key,
  });

  final DailyPrayerTimes times;
  final Prayer? next;

  /// Gregorian date to convert to Hijri (already Maghrib-rolled by the caller);
  /// null hides the date block. The [gregorianDate] (civil, for the line beneath)
  /// defaults to it when omitted.
  final DateTime? hijriBaseDate;
  final DateTime? gregorianDate;
  final int hijriAdjustment;

  /// Persist a changed ± day correction; null hides the adjust control.
  final ValueChanged<int>? onAdjustHijri;

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
            if (hijriBaseDate != null) ...[
              const SizedBox(height: 12),
              _HijriDateLabel(
                baseDate: hijriBaseDate!,
                gregorianDate: gregorianDate ?? hijriBaseDate!,
                initialAdjustment: hijriAdjustment,
                onAdjust: onAdjustHijri,
              ),
            ],
            const SizedBox(height: 12),
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
    final fg = isNext
        ? cs.onPrimaryContainer
        : (muted ? cs.onSurfaceVariant : cs.onSurface);
    final weight =
        isNext ? FontWeight.w700 : (muted ? FontWeight.w400 : FontWeight.w500);
    final window = forbidden;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (muted) ...[
                Icon(Icons.wb_twilight_rounded, size: 16, color: fg),
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
                  color: fg,
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
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(Icons.do_not_disturb_on_outlined, size: 13, color: gold),
          const SizedBox(width: 6),
          Text(
            'No prayer · ${formatPrayerTime(window.start)}'
            '–${formatPrayerTime(window.end)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: gold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Islamic date for the audience: the Hijri date in Urdu (Nastaliq + Urdu
/// numerals) over the Gregorian date. A discreet ± control nudges the Hijri day
/// (clamped ±2) to match the local moon-sighting; the change persists via
/// [onAdjust]. Local state so the nudge updates instantly without reopening.
class _HijriDateLabel extends StatefulWidget {
  const _HijriDateLabel({
    required this.baseDate,
    required this.gregorianDate,
    required this.initialAdjustment,
    this.onAdjust,
  });

  final DateTime baseDate;
  final DateTime gregorianDate;
  final int initialAdjustment;
  final ValueChanged<int>? onAdjust;

  @override
  State<_HijriDateLabel> createState() => _HijriDateLabelState();
}

class _HijriDateLabelState extends State<_HijriDateLabel> {
  late int _adj = widget.initialAdjustment;

  void _nudge(int delta) {
    final next = (_adj + delta).clamp(-2, 2);
    if (next == _adj) return;
    setState(() => _adj = next);
    widget.onAdjust?.call(_adj);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hijri =
        HijriDate.fromGregorian(widget.baseDate, adjustmentDays: _adj);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.onAdjust != null) ...[
          _NudgeButton(
            icon: Icons.remove_rounded,
            tooltip: 'Hijri −1 day (moon sighting)',
            onTap: () => _nudge(-1),
            color: cs.onSurfaceVariant,
          ),
          if (_adj != 0)
            Text(
              _adj > 0 ? '+$_adj' : '$_adj',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          _NudgeButton(
            icon: Icons.add_rounded,
            tooltip: 'Hijri +1 day (moon sighting)',
            onTap: () => _nudge(1),
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hijri.urduLong,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppTheme.urduFontFamily,
                  height: 2,
                  color: cs.onSurface,
                ),
              ),
              Text(
                formatGregorianDate(widget.gregorianDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onTap,
        color: color,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
}
