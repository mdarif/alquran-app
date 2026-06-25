import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/reminder_occurrence.dart';
import '../../domain/entities/sunnah_events.dart';
import '../../domain/repositories/reminder_settings_repository.dart';
import '../../domain/scheduling/notification_scheduler.dart';
import '../../domain/scheduling/occurrence_engine.dart';
import '../../domain/scheduling/reminder_payload.dart';
import 'reminders_state.dart';

/// Drives the Sunnah reminders: persists the master switch, requests permission,
/// and (re)schedules a ROLLING WINDOW of notifications. Mirrors `PrayerTimesCubit`
/// discipline — injected `clock`, no internal Timer, an idempotent `refresh()`
/// (called on app-resume) that recomputes + reschedules so each new month's
/// Hijri events roll into the window (and stays under the iOS 64-pending cap).
class RemindersCubit extends Cubit<RemindersState> {
  RemindersCubit(
    this._settings,
    this._scheduler, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(_initial(_settings, clock ?? DateTime.now));

  final ReminderSettingsRepository _settings;
  final NotificationScheduler _scheduler;
  final DateTime Function() _clock;
  final OccurrenceEngine _engine = const OccurrenceEngine();

  /// Cap on one-shot notifications scheduled at once (iOS allows 64 pending;
  /// keep headroom — the weekly Al-Kahf takes one more slot).
  static const int _maxOneShots = 50;

  static RemindersState _initial(
    ReminderSettingsRepository settings,
    DateTime Function() clock,
  ) {
    final enabled = settings.enabled;
    return RemindersState(
      enabled: enabled,
      upcoming: enabled ? _upNext(clock()) : const [],
    );
  }

  static List<ReminderOccurrence> _upNext(DateTime now) =>
      const OccurrenceEngine().upNext(now);

  /// Turn reminders on: request OS permission, then nudge toward RELIABLE
  /// delivery (allow exact alarms + exempt from battery optimization — both
  /// self-guarding, prompted only when missing), persist, schedule the window.
  Future<void> enable() async {
    final granted = await _scheduler.requestPermission();
    if (!granted) {
      emit(state.copyWith(permissionGranted: false));
      return;
    }
    await _scheduler.requestExactAlarmPermission();
    if (!await _scheduler.isBatteryOptimizationExempt()) {
      await _scheduler.requestBatteryOptimizationExemption();
    }
    await _settings.setEnabled(true);
    await _rescheduleAll();
  }

  /// Turn reminders off: cancel everything.
  Future<void> disable() async {
    await _settings.setEnabled(false);
    await _scheduler.cancelAll();
    emit(const RemindersState(enabled: false, permissionGranted: true));
  }

  /// Re-run the battery-optimization prompt (from the sheet's reliability hint).
  Future<void> fixReliability() async {
    await _scheduler.requestBatteryOptimizationExemption();
    await refresh();
  }

  /// Recompute + reschedule on app-resume (catches day/month rollover; reflects
  /// OS-level permission revocation).
  Future<void> refresh() async {
    if (!_settings.enabled) {
      emit(const RemindersState());
      return;
    }
    final granted = await _scheduler.hasPermission();
    if (!granted) {
      emit(
        RemindersState(
          enabled: true,
          permissionGranted: false,
          upcoming: _upNext(_clock()),
        ),
      );
      return;
    }
    await _rescheduleAll();
  }

  /// The rolling window: cancel all, schedule the next one-shots + the single
  /// weekly Al-Kahf, then publish the next few for Home.
  Future<void> _rescheduleAll() async {
    final now = _clock();
    final all = _engine.upcoming(now);
    await _scheduler.cancelAll();

    // One-shots for non-weekly events.
    final oneShots = all.where((o) => !o.event.weekly).take(_maxOneShots);
    for (final o in oneShots) {
      await _scheduler.scheduleOneShot(
        id: o.notificationId,
        fireAt: o.fireAt,
        title: o.title,
        body: o.body,
        payload: o.opensAlKahf ? openAlKahfPayload : null,
      );
    }

    // A single repeating notification per weekly event (e.g. Al-Kahf).
    for (final e in sunnahEvents.where((e) => e.weekly)) {
      await _scheduler.scheduleWeekly(
        id: e.idBase,
        weekday: e.weeklyWeekday!,
        hour: OccurrenceEngine.fireHour,
        minute: OccurrenceEngine.fireMinute,
        title: e.title,
        body: e.body,
        payload: e.opensAlKahf ? openAlKahfPayload : null,
      );
    }

    final exempt = await _scheduler.isBatteryOptimizationExempt();
    final exact = await _scheduler.canScheduleExact();
    emit(
      RemindersState(
        enabled: true,
        permissionGranted: true,
        batteryOptimized: !exempt,
        exactAlarmsAllowed: exact,
        upcoming: _engine.upNext(now),
      ),
    );
  }

  /// DEBUG ONLY (surfaced under `kDebugMode`): re-open the exact-alarm system
  /// screen, then refresh the live delivery status.
  Future<void> fixExactAlarms() async {
    await _scheduler.requestExactAlarmPermission();
    await refresh();
  }

  /// DEBUG ONLY: fire a real SCHEDULED notification ~2 minutes out through the
  /// live AlarmManager path — the only way to prove on-device delivery (an
  /// immediate `show` always works and would prove nothing). Returns a short
  /// report: the captured error if scheduling threw, else the OS pending count
  /// (so 0 pending ⇒ scheduling silently failed; ≥1 ⇒ queued, watch for the
  /// fire). Lock the phone and wait ~2 min.
  Future<String> scheduleDeliveryTest() async {
    final error = await _scheduler.scheduleOneShotDebug(
      id: 99,
      fireAt: _clock().add(const Duration(minutes: 2)),
      title: 'Reminder delivery test',
      body: 'Scheduled ~2 min ago. Seeing this means Android delivery works.',
    );
    if (error != null) return 'Schedule FAILED — $error';
    final pending = await _scheduler.pendingCount();
    return 'Scheduled ✓ — $pending queued. Lock the phone, wait ~2 min.';
  }
}
