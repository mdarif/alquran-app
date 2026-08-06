import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_navigator.dart';
import '../../../../core/feature_flags.dart';
import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../../prayer_times/domain/location/location_provider.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_state.dart';
import '../../../prayer_times/presentation/cubit/prayer_times_cubit.dart';
import '../../../reminders/domain/entities/reminder_occurrence.dart';
import '../../../reminders/domain/scheduling/reminder_payload.dart';
import '../../../reminders/presentation/cubit/reminders_cubit.dart';
import '../../../reminders/presentation/cubit/reminders_state.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String _shortDate(DateTime d) =>
    '${weekdayName(d).substring(0, 3)} ${d.day} ${_monthAbbr[d.month - 1]}';

/// "Today"/"Tomorrow" for the near days, else the short date. Display only.
String _relativeDate(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return _shortDate(d);
}

/// One place for both reminder types (Sunnah reminders + Salat notifications):
/// a uniform title/toggle/info-button row each, so there's a single interaction
/// model instead of one row opening a sheet and the other toggling bare inline.
/// Richer content (upcoming events, reliability hints, debug delivery) expands
/// under a row only while that reminder is enabled. Reached from Settings and
/// the app-bar bell — same screen everywhere reminders are configured.
class RemindersSettingsPage extends StatelessWidget {
  const RemindersSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const showSunnah = FeatureFlags.sunnahReminders;
    const showSalat =
        FeatureFlags.prayerTimes && FeatureFlags.prayerTimeNotifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        key: WidgetKeys.remindersPage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: const [
            if (showSunnah) _SunnahRemindersSection(),
            if (showSalat) _SalatNotificationsSection(),
          ],
        ),
      ),
    );
  }
}

/// A small anchored tooltip — dismisses on an outside tap instead of opening a
/// modal dialog. Content is kept to a few short lines rather than one dense
/// paragraph.
Future<void> _showInfoPopover(
  BuildContext context, {
  required String title,
  required List<String> lines,
}) {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight =
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
  final iconCenter = topLeft.dx + box.size.width / 2;
  const width = 228.0;
  final bubbleLeft = (iconCenter - width + 28).clamp(
    16.0,
    overlay.size.width - width - 16,
  );
  final bubbleTop = bottomRight.dy + 2;
  final arrowCenter = (topLeft.dx + box.size.width / 2 - bubbleLeft).clamp(
    18.0,
    width - 18,
  );
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 110),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            width: width,
            child: _InfoTooltip(
              title: title,
              lines: lines,
              arrowCenter: arrowCenter.toDouble(),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _InfoTooltip extends StatelessWidget {
  const _InfoTooltip({
    required this.title,
    required this.lines,
    required this.arrowCenter,
  });

  final String title;
  final List<String> lines;
  final double arrowCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? cs.inverseSurface : cs.surface;
    final foreground = isDark ? cs.onInverseSurface : cs.onSurface;
    final secondary = isDark
        ? cs.onInverseSurface.withValues(alpha: 0.82)
        : cs.onSurfaceVariant;
    final borderColor =
        isDark ? null : cs.outlineVariant.withValues(alpha: 0.6);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: arrowCenter - 8),
            child: CustomPaint(
              painter: _TooltipCaretPainter(
                color: background,
                borderColor: borderColor,
              ),
              child: const SizedBox(width: 16, height: 8),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(7),
              border:
                  borderColor == null ? null : Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.10),
                  blurRadius: isDark ? 10 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: DefaultTextStyle(
                style: theme.textTheme.bodySmall!.copyWith(
                  color: secondary,
                  height: 1.24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(line),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipCaretPainter extends CustomPainter {
  const _TooltipCaretPainter({required this.color, this.borderColor});

  final Color color;
  final Color? borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final stroke = borderColor;
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_TooltipCaretPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

class _SunnahRemindersSection extends StatelessWidget {
  const _SunnahRemindersSection();

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
        return _ReminderRow(
          title: 'Sunnah Reminders',
          switchKey: WidgetKeys.sunnahRemindersToggle,
          infoKey: WidgetKeys.sunnahRemindersInfoButton,
          enabled: state.enabled,
          onChanged: (on) => _toggle(context, bloc, on),
          onInfo: (iconContext) => _showInfoPopover(
            iconContext,
            title: 'Sunnah Reminders',
            lines: const [
              'Surah Al-Kahf before Maghrib on Fridays.',
              'White Days: 13th-15th of each Hijri month.',
              'Ashura, Arafah, and the first 10 days of Dhul Hijjah.',
            ],
          ),
          child: !state.enabled
              ? null
              : !state.permissionGranted
                  ? const _PermissionDeniedHint()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.batteryOptimized) ...[
                          const SizedBox(height: 8),
                          _ReliabilityHint(onFix: bloc.fixReliability),
                        ],
                        if (kDebugMode)
                          _SunnahDebugPanel(state: state, cubit: bloc),
                        if (state.upcoming.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Up next',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          for (final o in state.upcoming)
                            _OccurrenceRow(occurrence: o),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    RemindersCubit cubit,
    bool on,
  ) async {
    if (!on) {
      await cubit.disable();
      return;
    }
    await cubit.enable();
    if (!context.mounted) return;
    if (!cubit.state.enabled) {
      _showPermissionDeniedSnack(context);
    }
  }
}

class _SalatNotificationsSection extends StatelessWidget {
  const _SalatNotificationsSection();

  @override
  Widget build(BuildContext context) {
    PrayerNotificationsCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerNotificationsCubit>(context);
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();
    final bloc = cubit;

    return BlocBuilder<PrayerNotificationsCubit, PrayerNotificationsState>(
      bloc: bloc,
      builder: (context, state) {
        return _ReminderRow(
          title: 'Salat Notifications',
          switchKey: WidgetKeys.prayerNotificationsToggle,
          infoKey: WidgetKeys.prayerNotificationsInfoButton,
          enabled: state.enabled,
          onChanged: (on) => _toggle(context, bloc, on),
          onInfo: (iconContext) => _showInfoPopover(
            iconContext,
            title: 'Salat Notifications',
            lines: const [
              'One reminder for each daily prayer.',
              'Times use your device location.',
              'Scheduled on-device; nothing is sent anywhere.',
            ],
          ),
          child: !state.enabled
              ? null
              : !state.permissionGranted
                  ? const _PermissionDeniedHint()
                  : !state.hasLocation
                      ? _NoLocationHint(
                          onEnable: () => _enableLocation(context, bloc),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.batteryOptimized) ...[
                              const SizedBox(height: 8),
                              _ReliabilityHint(onFix: bloc.fixReliability),
                            ],
                            const SizedBox(height: 8),
                            _SoundCheckHint(
                              onTap: () => _runSoundCheck(context, bloc),
                            ),
                            if (kDebugMode) _SalatDebugButton(cubit: bloc),
                          ],
                        ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    PrayerNotificationsCubit cubit,
    bool on,
  ) async {
    if (!on) {
      await cubit.disable();
      return;
    }
    await cubit.enable();
    if (!context.mounted) return;
    if (!cubit.state.enabled) {
      _showPermissionDeniedSnack(context);
      return;
    }
    if (cubit.state.permissionGranted && cubit.state.hasLocation) {
      await _runSoundCheck(context, cubit);
    }
  }

  /// Fires an immediate test notification and asks the user whether they
  /// heard/felt it — catching a silenced Ring/Vibrate toggle (an OEM-level
  /// setting the app cannot set programmatically; see
  /// docs/notification-reliability-notes.md) right when notifications are
  /// enabled, instead of at the next missed prayer.
  Future<void> _runSoundCheck(
    BuildContext context,
    PrayerNotificationsCubit cubit,
  ) async {
    await cubit.sendSoundCheck();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sending a test Salat notification…'),
          duration: Duration(seconds: 3),
        ),
      );
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!context.mounted) return;
    final heard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Did you hear or feel it?'),
        content: const Text(
          'We just sent a test Salat notification. If your phone stayed '
          'silent, open Al Quran in your phone\'s notification Settings and '
          'turn on Ring and Vibrate — some phones keep those off, which '
          'silences prayer notifications no matter what the app does.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No, didn't notice"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, got it'),
          ),
        ],
      ),
    );
    if (heard == false) {
      await cubit.openSoundSettings();
    }
  }

  Future<void> _enableLocation(
    BuildContext context,
    PrayerNotificationsCubit prayerNotifications,
  ) async {
    PrayerTimesCubit? prayerTimes;
    try {
      prayerTimes = BlocProvider.of<PrayerTimesCubit>(context);
    } catch (_) {
      prayerTimes = null;
    }
    if (prayerTimes == null) return;
    await prayerTimes.enableLocation();
    if (!context.mounted) return;
    final status = prayerTimes.state.status;
    if (status != null && status != LocationStatus.ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_locationStatusMessage(status)),
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }
    // Same underlying PrayerTimesRepository, so once location lands the
    // notifications cubit just needs to re-read it and reschedule.
    await prayerNotifications.refresh();
  }

  String _locationStatusMessage(LocationStatus status) => switch (status) {
        LocationStatus.serviceOff =>
          'Turn on location services to enable Salat notifications.',
        LocationStatus.deniedForever =>
          'Enable location for Al Quran in Settings to receive Salat '
              'notifications.',
        _ => 'Location is needed for Salat notifications.',
      };
}

void _showPermissionDeniedSnack(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off for Al Quran in your phone Settings. '
          'Enable them there, then try again.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
}

/// Uniform title + toggle + info-button row, with optional expanded content
/// shown directly underneath (only while [enabled]).
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.title,
    required this.switchKey,
    required this.infoKey,
    required this.enabled,
    required this.onChanged,
    required this.onInfo,
    this.child,
  });

  final String title;
  final Key switchKey;
  final Key infoKey;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final ValueChanged<BuildContext> onInfo;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              SizedBox.square(
                key: infoKey,
                dimension: 40,
                child: Builder(
                  builder: (iconContext) => IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const AppIcon(
                      AppIcons.about,
                      size: AppIconSize.label,
                    ),
                    onPressed: () => onInfo(iconContext),
                  ),
                ),
              ),
              Switch.adaptive(
                key: switchKey,
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _PermissionDeniedHint extends StatelessWidget {
  const _PermissionDeniedHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Allow notifications in Settings to receive these reminders.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _NoLocationHint extends StatelessWidget {
  const _NoLocationHint({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEnable,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AppIcon(
                AppIcons.locationSearch,
                size: AppIconSize.label,
                color: cs.tertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enable location so prayer times can be calculated for '
                  'your area. Tap to turn it on.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: AppIconSize.inline,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({required this.occurrence});

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
            AppIcon(AppIcons.alKahf, size: AppIconSize.label, color: cs.primary)
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
            AppIcon(
              AppIcons.chevronRight,
              size: AppIconSize.inline,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (!isKahf) return content;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // close the Reminders page first
        unawaited(routeFromPayload(openAlKahfPayload));
      },
      child: content,
    );
  }
}

/// Shown when the app isn't exempt from battery optimization — the OS may
/// delay or drop reminders. Tapping re-runs the system exemption prompt.
class _ReliabilityHint extends StatelessWidget {
  const _ReliabilityHint({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onFix,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AppIcon(
                AppIcons.batteryAlert,
                size: AppIconSize.label,
                color: cs.tertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your phone may delay reminders. Tap to allow background '
                  'activity for reliable delivery.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: AppIconSize.inline,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Always visible while Salat Notifications is on — lets a user re-run the
/// sound check on demand (they may have dismissed the initial prompt, or the
/// phone was on silent at the time). See docs/notification-reliability-notes.md.
class _SoundCheckHint extends StatelessWidget {
  const _SoundCheckHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              AppIcon(
                AppIcons.reminders,
                size: AppIconSize.label,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Didn't hear the test notification? Tap to check again.",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: AppIconSize.inline,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DEBUG ONLY (`kDebugMode`) — never ships. A live readout of the three things
/// that gate Android scheduled delivery, plus a button that schedules a REAL
/// notification ~2 min out through AlarmManager.
class _SunnahDebugPanel extends StatefulWidget {
  const _SunnahDebugPanel({required this.state, required this.cubit});

  final RemindersState state;
  final RemindersCubit cubit;

  @override
  State<_SunnahDebugPanel> createState() => _SunnahDebugPanelState();
}

class _SunnahDebugPanelState extends State<_SunnahDebugPanel> {
  String? _report;

  RemindersState get state => widget.state;
  RemindersCubit get cubit => widget.cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
              icon:
                  const AppIcon(AppIcons.scheduleTest, size: AppIconSize.label),
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
              AppIcon(
                ok ? AppIcons.statusPass : AppIcons.statusFail,
                filled: true,
                size: AppIconSize.inline,
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

/// DEBUG ONLY (`kDebugMode`) — schedules a real salat notification ~2 minutes
/// out through the live alarm path, replacing the old standalone Settings row.
class _SalatDebugButton extends StatefulWidget {
  const _SalatDebugButton({required this.cubit});

  final PrayerNotificationsCubit cubit;

  @override
  State<_SalatDebugButton> createState() => _SalatDebugButtonState();
}

class _SalatDebugButtonState extends State<_SalatDebugButton> {
  String? _report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: WidgetKeys.prayerNotificationsTestButton,
              onPressed: () async {
                final report = await widget.cubit.scheduleDeliveryTest();
                debugPrint('[prayer-notifications] delivery test: $report');
                if (mounted) setState(() => _report = report);
              },
              icon:
                  const AppIcon(AppIcons.scheduleTest, size: AppIconSize.label),
              label: const Text('Schedule salat test'),
            ),
          ),
          if (_report != null) ...[
            const SizedBox(height: 6),
            Text(
              _report!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _report!.startsWith('Scheduled')
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
