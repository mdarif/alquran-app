import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../reminders/domain/scheduling/notification_delivery_status.dart';
import '../../../reminders/domain/scheduling/notification_scheduler.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/entities/geo_location.dart';
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
  static const int soundCheckId = _idBase + 98;
  static const int _windowDays = 2;
  static const int _maxPerDay = 5;

  /// Every id this feature owns — the rolling prayer window PLUS the two test
  /// ids. The test ids must be in here: salat notifications are `autoCancel:
  /// false` (a prayer nudge shouldn't vanish on the next unlock), so a sound
  /// check or delivery test that nothing cancels sits in the shade forever,
  /// and once ~4 of ours are stacked the OS auto-bundles the app's
  /// notifications into its "Aggregate" group.
  static List<int> get notificationIds => [
        for (var id = _idBase; id < _idBase + (_windowDays * _maxPerDay); id++)
          id,
        soundCheckId,
        debugTestId,
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
    await requestReliableNotificationDelivery(_scheduler);
    await _settings.setEnabled(true);
    await _reschedule();
  }

  Future<void> disable() async {
    await _settings.setEnabled(false);
    await _cancelPrayerNotifications();
    emit(const PrayerNotificationsState(enabled: false));
  }

  Future<void> turnOnAnyway() async {
    await _settings.setAllowZoneMismatchAlerts(true);
    await _reschedule();
  }

  /// Re-run the battery-optimization prompt (from the reliability hint).
  Future<void> fixReliability() async {
    await _scheduler.requestBatteryOptimizationExemption();
    await refresh();
  }

  /// DEBUG ONLY: re-open the exact-alarm system screen, then refresh status.
  Future<void> fixExactAlarms() async {
    await _scheduler.requestExactAlarmPermission();
    await refresh();
  }

  /// Posts a test Salat notification IMMEDIATELY (not via AlarmManager) so a
  /// fresh "enable" can confirm — right away, instead of at the next actual
  /// prayer time — whether the user will actually hear/feel it. It used to go
  /// through the alarm path "3 seconds out", which the OS is free to batch
  /// minutes away: the "did you hear it?" prompt then asked about a
  /// notification that hadn't been posted yet. Some OEM skins (ColorOS/OxygenOS confirmed) hide
  /// an app-level Ring/Vibrate toggle above the notification channel that this
  /// app cannot set programmatically; [openSoundSettings] is the follow-up
  /// when the answer is "no". See docs/notification-reliability-notes.md.
  Future<void> sendSoundCheck() async {
    await _scheduler.showNow(
      id: soundCheckId,
      title: 'Salat Notifications',
      body: 'This is what a Salat notification sounds/feels like.',
      soundName: 'salat_nudge',
    );
  }

  /// Opens the APP-level notification settings for a user who didn't hear the
  /// sound check — deliberately NOT the Salat channel page.
  ///
  /// On ColorOS/OxygenOS the `Ring` and `Vibrate` switches that actually
  /// silence everything live on the app page, above the channels; the channel
  /// page only offers "Allow notifications / Set as silent / Lock screen /
  /// Banner". Confirmed on a OnePlus where both were off while every channel
  /// dump looked perfectly healthy (they are invisible to `dumpsys` and to
  /// every Android API, so the app can neither read nor set them — pointing the
  /// user at the right screen is all we can do). Deep-linking to the channel
  /// sent people to the one page where the cause could not be seen.
  Future<void> openSoundSettings() async {
    await _scheduler.openNotificationSettings();
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
    if (_zoneDiffers(location, now) && !_settings.allowZoneMismatchAlerts) {
      await _cancelPrayerNotifications();
      emit(const PrayerNotificationsState(enabled: true, zoneMismatch: true));
      return;
    }
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
          payload: prayerTimesPayload(prayer: prayer, fireAt: time),
          soundName: 'salat_nudge',
        );
        scheduled++;
      }
    }

    final delivery = await NotificationDeliveryStatus.read(_scheduler);
    emit(
      PrayerNotificationsState(
        enabled: true,
        permissionGranted: true,
        delivery: delivery,
        scheduledCount: scheduled,
      ),
    );
  }

  bool _zoneDiffers(GeoLocation location, DateTime now) {
    final id = location.timezoneId;
    if (id == null) return false;
    try {
      return tz.TZDateTime.from(now, tz.getLocation(id)).timeZoneOffset !=
          tz.TZDateTime.from(now, tz.local).timeZoneOffset;
    } catch (_) {
      return false;
    }
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
      payload: _nearestPrayerPayload(fireAt),
      soundName: 'salat_nudge',
    );
    if (error != null) return 'Schedule FAILED - $error';
    final pending = await _scheduler.pendingCount();
    final mode = _scheduler.lastScheduleWasExact
        ? 'exact'
        : 'INEXACT - OS refused exact alarms, delivery may be up to an hour late';
    return 'Scheduled ($mode) - $pending queued. Lock the phone, wait ~2 min.';
  }

  /// The salah whose time is closest to [at] — so a debug test fired "now"
  /// reads as whatever prayer is actually current (e.g. Asr at 4pm), not a
  /// fixed placeholder. Falls back to a generic label if location/times
  /// aren't available (shouldn't happen — the caller only reaches here once
  /// notifications are already permitted and the row is visible).
  String _nearestPrayerLabel(DateTime at) {
    return _nearestPrayer(at)?.$1.label ?? 'Prayer';
  }

  String _nearestPrayerPayload(DateTime at) {
    final nearest = _nearestPrayer(at);
    if (nearest == null) return openPrayerTimesPayload;
    return prayerTimesPayload(prayer: nearest.$1, fireAt: at);
  }

  (Prayer, DateTime)? _nearestPrayer(DateTime at) {
    final location = _prayerTimes.location;
    final day = location == null ? null : _prayerTimes.timesFor(location, at);
    if (day == null) return null;
    (Prayer, DateTime)? nearest;
    Duration? nearestDiff;
    for (final entry in day.schedule) {
      final diff = entry.$2.difference(at).abs();
      if (nearestDiff == null || diff < nearestDiff) {
        nearest = entry;
        nearestDiff = diff;
      }
    }
    return nearest;
  }

  String _formatTime(DateTime time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
