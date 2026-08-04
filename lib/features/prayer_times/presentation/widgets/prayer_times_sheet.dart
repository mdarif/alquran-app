import 'dart:async';

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
    this.notificationPrayer,
    this.notificationFireAt,
    this.hijriBaseDate,
    this.gregorianDate,
    this.initialNow,
    this.liveCountdown = true,
    super.key,
  });

  final DailyPrayerTimes times;
  final Prayer? next;
  final Prayer? notificationPrayer;
  final DateTime? notificationFireAt;
  final DateTime? initialNow;
  final bool liveCountdown;

  /// Gregorian date to convert to the Hijri (already Maghrib-rolled by the
  /// caller); null hides the date block. The [gregorianDate] (civil, for the line
  /// beneath) defaults to it when omitted.
  final DateTime? hijriBaseDate;
  final DateTime? gregorianDate;

  @override
  Widget build(BuildContext context) {
    return _PrayerTimesSheetBody(
      times: times,
      next: next,
      notificationPrayer: notificationPrayer,
      notificationFireAt: notificationFireAt,
      hijriBaseDate: hijriBaseDate,
      gregorianDate: gregorianDate,
      initialNow: initialNow,
      liveCountdown: liveCountdown,
    );
  }
}

class _PrayerTimesSheetBody extends StatefulWidget {
  const _PrayerTimesSheetBody({
    required this.times,
    required this.next,
    this.notificationPrayer,
    this.notificationFireAt,
    this.hijriBaseDate,
    this.gregorianDate,
    this.initialNow,
    this.liveCountdown = true,
  });

  final DailyPrayerTimes times;
  final Prayer? next;
  final Prayer? notificationPrayer;
  final DateTime? notificationFireAt;
  final DateTime? hijriBaseDate;
  final DateTime? gregorianDate;
  final DateTime? initialNow;
  final bool liveCountdown;

  @override
  State<_PrayerTimesSheetBody> createState() => _PrayerTimesSheetBodyState();
}

class _PrayerTimesSheetBodyState extends State<_PrayerTimesSheetBody> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = widget.initialNow ?? DateTime.now();
    if (widget.liveCountdown) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final times = widget.times;
    final rowNext = times.nextAfter(_now)?.$1;
    final hasActiveSalah = times.currentSalahAt(_now) != null;
    final suppressNextBadge =
        !hasActiveSalah && times.forbiddenAt(_now) == null;
    final notificationPrayer = widget.notificationPrayer;
    final notificationCurrent =
        notificationPrayer != null && _activePrayer == notificationPrayer;
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
                Text(
                  "Today's Prayer Times",
                  style: theme.textTheme.titleMedium,
                ),
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
            if (widget.hijriBaseDate != null) ...[
              const SizedBox(height: 10),
              _HijriDateLabel(
                baseDate: widget.hijriBaseDate!,
                gregorianDate: widget.gregorianDate ?? widget.hijriBaseDate!,
              ),
            ],
            const SizedBox(height: 12),
            _PrayerFocusCard(
              times: times,
              now: _now,
              next: rowNext,
              notificationPrayer: notificationPrayer,
              notificationFireAt: widget.notificationFireAt,
            ),
            const SizedBox(height: 8),
            // Fajr, then Sunrise as a muted marker (end of Fajr / Ishraq — not a
            // salah, so never highlighted), then the remaining four prayers.
            _PrayerRow(
              label: Prayer.fajr.label,
              time: times.fajr,
              isNext: rowNext == Prayer.fajr,
              badge: _badgeFor(
                Prayer.fajr,
                notificationPrayer,
                notificationCurrent,
                suppressNextBadge,
              ),
            ),
            _PrayerRow(
              label: 'Sunrise',
              time: times.sunrise,
              isNext: rowNext == Prayer.sunrise,
              muted: true,
              badge: _badgeFor(
                Prayer.sunrise,
                notificationPrayer,
                notificationCurrent,
                suppressNextBadge,
              ),
              forbidden: forbidden[ForbiddenReason.afterSunrise],
            ),
            for (final (prayer, time) in times.schedule.skip(1))
              _PrayerRow(
                label: prayer.label,
                time: time,
                isNext: prayer == rowNext,
                badge: _badgeFor(
                  prayer,
                  notificationPrayer,
                  notificationCurrent,
                  suppressNextBadge,
                ),
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

  Prayer? get _activePrayer => widget.times.currentSalahAt(_now)?.$1;

  String? _badgeFor(
    Prayer prayer,
    Prayer? notificationPrayer,
    bool notificationCurrent,
    bool suppressNextBadge,
  ) {
    if (notificationPrayer == prayer) {
      return notificationCurrent ? 'Now' : 'Notified';
    }
    if (prayer == _activePrayer) return 'Now';
    if (suppressNextBadge) return null;
    if (prayer == widget.times.nextAfter(_now)?.$1) return 'Next';
    return null;
  }
}

class _PrayerFocusCard extends StatelessWidget {
  const _PrayerFocusCard({
    required this.times,
    required this.now,
    required this.next,
    this.notificationPrayer,
    this.notificationFireAt,
  });

  final DailyPrayerTimes times;
  final DateTime now;
  final Prayer? next;
  final Prayer? notificationPrayer;
  final DateTime? notificationFireAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = times.currentSalahAt(now);
    final forbidden = times.forbiddenAt(now);
    final resolvedNext = _resolvedNext();
    if (forbidden != null) {
      final remaining = forbidden.end.difference(now);
      return _ForbiddenFocusCard(
        window: forbidden,
        remaining: remaining.isNegative ? Duration.zero : remaining,
      );
    }
    if (resolvedNext == null) return const SizedBox.shrink();

    final focusPrayer = notificationPrayer ?? active?.$1;
    if (focusPrayer == null) {
      return _NextPrayerFocusCard(
        prayer: resolvedNext.$1,
        at: resolvedNext.$2,
        remaining: resolvedNext.$2.difference(now),
      );
    }

    final focusTime = notificationFireAt ?? _timeFor(focusPrayer);
    final start = active?.$2;
    final end = active?.$3 ?? resolvedNext.$2;
    final total = end.difference(start ?? focusTime);
    final elapsed = now.difference(start ?? focusTime);
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final remaining = resolvedNext.$2.difference(now);
    final remainingText = _formatRemaining(
      remaining.isNegative ? Duration.zero : remaining,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _FocusEndpoint(
                    title: focusPrayer.label,
                    time: focusTime,
                    subtitle: notificationPrayer == null
                        ? 'Current'
                        : focusPrayer == active?.$1
                            ? 'Notified now'
                            : 'Notification',
                  ),
                ),
                Expanded(
                  child: _FocusEndpoint(
                    title: resolvedNext.$1.label,
                    time: resolvedNext.$2,
                    subtitle: 'Next',
                    alignEnd: true,
                    emphasized: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: cs.surface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              remainingText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Prayer, DateTime)? _resolvedNext() {
    final activePrayer = times.currentSalahAt(now)?.$1;
    final fallback = _nextSalahAfterActive(activePrayer);
    if (next == null) return fallback;
    final fromState = (next!, _timeFor(next!));
    return next!.isSalah && next != activePrayer && fromState.$2.isAfter(now)
        ? fromState
        : fallback;
  }

  (Prayer, DateTime)? _nextSalahAfterActive(Prayer? activePrayer) {
    for (final entry in times.schedule) {
      if (entry.$1 == activePrayer) continue;
      if (entry.$2.isAfter(now)) return entry;
    }
    return null;
  }

  DateTime _timeFor(Prayer prayer) => switch (prayer) {
        Prayer.fajr => times.fajr,
        Prayer.sunrise => times.sunrise,
        Prayer.dhuhr => times.dhuhr,
        Prayer.asr => times.asr,
        Prayer.maghrib => times.maghrib,
        Prayer.isha => times.isha,
      };

  String _formatRemaining(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _NextPrayerFocusCard extends StatelessWidget {
  const _NextPrayerFocusCard({
    required this.prayer,
    required this.at,
    required this.remaining,
  });

  final Prayer prayer;
  final DateTime at;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final remainingText = _formatRemaining(
      remaining.isNegative ? Duration.zero : remaining,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Next Prayer',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  prayer.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  formatPrayerTime(at),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              remainingText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _ForbiddenFocusCard extends StatelessWidget {
  const _ForbiddenFocusCard({required this.window, required this.remaining});

  final ForbiddenWindow window;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    final fg = cs.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.13),
        border: Border.all(color: gold.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(
                  AppIcons.forbidden,
                  size: AppIconSize.inline,
                  color: gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No voluntary prayer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Until ${formatPrayerTime(window.end)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              window.reason.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _formatRemaining(remaining),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: gold,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _FocusEndpoint extends StatelessWidget {
  const _FocusEndpoint({
    required this.title,
    required this.time,
    required this.subtitle,
    this.alignEnd = false,
    this.emphasized = true,
  });

  final String title;
  final DateTime time;
  final String subtitle;
  final bool alignEnd;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final align = alignEnd ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          formatPrayerTime(time),
          textAlign: align,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onPrimaryContainer,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          title,
          textAlign: align,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onPrimaryContainer,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          subtitle,
          textAlign: align,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onPrimaryContainer.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.label,
    required this.time,
    required this.isNext,
    this.muted = false,
    this.badge,
    this.forbidden,
  });

  final String label;
  final DateTime time;
  final bool isNext;
  final String? badge;

  /// A non-salah marker (Sunrise) — dimmed and never highlightable as "next".
  final bool muted;

  /// The forbidden-for-prayer window bounded by this row, if any — rendered as a
  /// small gold caption beneath it.
  final ForbiddenWindow? forbidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg =
        muted ? cs.onSurfaceVariant.withValues(alpha: 0.62) : cs.onSurface;
    final isCurrent = badge == 'Now' || badge == 'Notified';
    final isNextOnly = !isCurrent && isNext;
    final weight = isCurrent
        ? FontWeight.w700
        : (muted ? FontWeight.w400 : FontWeight.w500);
    final window = forbidden;
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent
            ? cs.primaryContainer.withValues(alpha: 0.55)
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
                  color: isCurrent ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 11),
              if (muted) ...[
                AppIcon(AppIcons.sunrise, size: AppIconSize.inline, color: fg),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    _StatusBadge(label: badge!),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight: weight,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                formatPrayerTime(time),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isCurrent || isNextOnly ? cs.primary : fg,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
        ),
      ),
    );
  }
}

/// The small gold prohibited-time caption beneath a row that bounds a forbidden
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
          AppIcon(
            AppIcons.forbidden,
            size: AppIconSize.dense,
            color: gold.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 5),
          Text(
            'No Nafl Prayer · ${formatPrayerTime(window.start)}'
            '–${formatPrayerTime(window.end)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold.withValues(alpha: 0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Islamic date for the audience, paired with the civil Gregorian date.
/// Both stay on one line: Hijri anchors the left edge, Gregorian balances the
/// right edge so neither reads like incidental metadata.
class _HijriDateLabel extends StatelessWidget {
  const _HijriDateLabel({required this.baseDate, required this.gregorianDate});

  final DateTime baseDate;
  final DateTime gregorianDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hijri = HijriDate.fromGregorianCorrected(baseDate);
    final dateStyle = theme.textTheme.titleSmall;
    // On a Sunnah occasion the Hijri date itself is gilded (gold + bolder).
    final isSunnah = sunnahOccasionName(baseDate) != null;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            hijri.formatted,
            overflow: TextOverflow.ellipsis,
            style: dateStyle?.copyWith(
              color: isSunnah ? gold : cs.onSurface,
              fontWeight: isSunnah ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatGregorianDate(gregorianDate),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: dateStyle?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
