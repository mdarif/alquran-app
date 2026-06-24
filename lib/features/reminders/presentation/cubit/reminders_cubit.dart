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
      upcoming: enabled ? _nextFew(clock()) : const [],
    );
  }

  static List<ReminderOccurrence> _nextFew(DateTime now) =>
      const OccurrenceEngine().upcoming(now).take(5).toList();

  /// Turn reminders on: request OS permission, persist, schedule the window.
  Future<void> enable() async {
    final granted = await _scheduler.requestPermission();
    if (!granted) {
      emit(state.copyWith(permissionGranted: false));
      return;
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

  /// Fire a notification right now, so the user can see what a reminder looks
  /// like (ensures permission first).
  Future<void> sendTestReminder() async {
    if (!await _scheduler.hasPermission()) {
      final granted = await _scheduler.requestPermission();
      if (!granted) {
        emit(state.copyWith(permissionGranted: false));
        return;
      }
    }
    await _scheduler.showTest(
      title: 'Sunnah reminder',
      body: 'This is how your Sunnah reminders will look.',
    );
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
          upcoming: _nextFew(_clock()),
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

    emit(
      RemindersState(
        enabled: true,
        permissionGranted: true,
        upcoming: all.take(5).toList(),
      ),
    );
  }
}
