import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../reminders/domain/scheduling/notification_scheduler.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/repositories/prayer_notification_settings_repository.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../../domain/scheduling/prayer_notification_payload.dart';
import 'prayer_notifications_state.dart';

class PrayerNotificationsCubit extends Cubit<PrayerNotificationsState> {
  PrayerNotificationsCubit(
    this._settings,
    this._scheduler,
    this._prayerTimes, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(PrayerNotificationsState(enabled: _settings.enabled));

  final PrayerNotificationSettingsRepository _settings;
  final NotificationScheduler _scheduler;
  final PrayerTimesRepository _prayerTimes;
  final DateTime Function() _clock;

  static const int _idBase = 20000;
  static const int debugTestId = _idBase + 99;
  static const int _windowDays = 2;
  static const int _maxPerDay = 5;

  static List<int> get notificationIds => [
        for (var id = _idBase; id < _idBase + (_windowDays * _maxPerDay); id++)
          id,
      ];

  Future<void> enable() async {
    final granted = await _scheduler.requestPermission();
    if (!granted) {
      emit(
        const PrayerNotificationsState(
          enabled: false,
          permissionGranted: false,
        ),
      );
      return;
    }
    await _settings.setEnabled(true);
    await _reschedule();
  }

  Future<void> disable() async {
    await _settings.setEnabled(false);
    await _cancelPrayerNotifications();
    emit(const PrayerNotificationsState(enabled: false));
  }

  Future<void> refresh() async {
    if (!_settings.enabled) {
      emit(const PrayerNotificationsState(enabled: false));
      return;
    }
    final granted = await _scheduler.hasPermission();
    if (!granted) {
      emit(
        const PrayerNotificationsState(
          enabled: true,
          permissionGranted: false,
        ),
      );
      return;
    }
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final location = _prayerTimes.location;
    if (location == null) {
      emit(
        const PrayerNotificationsState(
          enabled: true,
          hasLocation: false,
        ),
      );
      return;
    }

    await _cancelPrayerNotifications();

    final now = _clock();
    var scheduled = 0;
    for (var dayOffset = 0; dayOffset < _windowDays; dayOffset++) {
      final day = _prayerTimes.timesFor(
        location,
        now.add(Duration(days: dayOffset)),
      );
      if (day == null) continue;
      for (final (prayer, time) in day.schedule) {
        if (!prayer.isSalah || !time.isAfter(now)) continue;
        await _scheduler.scheduleOneShot(
          id: _idBase + scheduled,
          fireAt: time,
          title: 'Salat Time - ${prayer.label}',
          body: _formatTime(time),
          payload: openPrayerTimesPayload,
          soundName: 'salat_nudge',
        );
        scheduled++;
      }
    }

    emit(
      PrayerNotificationsState(
        enabled: true,
        permissionGranted: true,
        scheduledCount: scheduled,
      ),
    );
  }

  Future<void> _cancelPrayerNotifications() async {
    for (final id in notificationIds) {
      await _scheduler.cancel(id);
    }
  }

  /// DEBUG ONLY: schedules a real salat notification ~2 minutes out through the
  /// live alarm path, so device testing proves scheduled delivery rather than
  /// merely showing an immediate notification.
  Future<String> scheduleDeliveryTest() async {
    var granted = await _scheduler.hasPermission();
    if (!granted) {
      granted = await _scheduler.requestPermission();
    }
    if (!granted) {
      return 'Notifications not allowed - enable permission in Settings.';
    }
    final fireAt = _clock().add(const Duration(minutes: 2));
    final error = await _scheduler.scheduleOneShotDebug(
      id: debugTestId,
      fireAt: fireAt,
      title: 'Salat Time - ${_nearestPrayerLabel(fireAt)}',
      body: _formatTime(fireAt),
      payload: openPrayerTimesPayload,
      soundName: 'salat_nudge',
    );
    if (error != null) return 'Schedule FAILED - $error';
    final pending = await _scheduler.pendingCount();
    return 'Scheduled - $pending queued. Lock the phone, wait ~2 min.';
  }

  /// The salah whose time is closest to [at] — so a debug test fired "now"
  /// reads as whatever prayer is actually current (e.g. Asr at 4pm), not a
  /// fixed placeholder. Falls back to a generic label if location/times
  /// aren't available (shouldn't happen — the caller only reaches here once
  /// notifications are already permitted and the row is visible).
  String _nearestPrayerLabel(DateTime at) {
    final location = _prayerTimes.location;
    final day = location == null ? null : _prayerTimes.timesFor(location, at);
    if (day == null) return 'Prayer';
    (Prayer, DateTime)? nearest;
    Duration? nearestDiff;
    for (final entry in day.schedule) {
      final diff = entry.$2.difference(at).abs();
      if (nearestDiff == null || diff < nearestDiff) {
        nearest = entry;
        nearestDiff = diff;
      }
    }
    return nearest?.$1.label ?? 'Prayer';
  }

  String _formatTime(DateTime time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
