import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/scheduling/notification_scheduler.dart';

/// `flutter_local_notifications` + `timezone` implementation of
/// [NotificationScheduler]. The thin platform-touching layer (the pure
/// [OccurrenceEngine] does the date logic) — every plugin call is best-effort
/// and swallowed, like `WidgetPublisher`, so a notification hiccup never crashes
/// a reading session. Requires `tz.setLocalLocation(...)` to have run (main.dart).
class LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String? payload)? _onSelect;

  static const String _channelId = 'sunnah_reminders_v2';
  static const String _channelName = 'Sunnah Reminders';
  static const String _channelDesc =
      'Gentle reminders for Sunnah acts (Surah Al-Kahf, fasting days, etc.)';
  static const String _salatChannelId = 'salat_notifications_nature_v4';
  static const String _salatChannelName = 'Salat Notifications';
  static const String _salatChannelDesc =
      'Gentle salat-time nudges with a soft natural sound';
  static const String _salatGroupKey = 'com.almarfa.alquran.salat';
  static const String _sunnahGroupKey = 'com.almarfa.alquran.sunnah';
  static final Int64List _salatVibrationPattern = Int64List.fromList(
    const [0, 250, 160, 250],
  );

  /// Native bridge for the battery-optimization exemption (see MainActivity.kt).
  static const MethodChannel _native =
      MethodChannel('com.almarfa.al_quran/reminders');

  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {
    _onSelect = onSelect;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Don't prompt at init — permission is requested explicitly on enable.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (r) => _onSelect?.call(r.payload),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          _salatChannelId,
          _salatChannelName,
          description: _salatChannelDesc,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('salat_nudge'),
          enableVibration: true,
          vibrationPattern: _salatVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _android;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _ios;
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {
      // fall through
    }
    return false;
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final android = _android;
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _ios;
      if (ios != null) {
        final opts = await ios.checkPermissions();
        return opts?.isEnabled ?? false;
      }
    } catch (_) {
      // fall through
    }
    return false;
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<int> pendingCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return -1;
    }
  }

  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {
    try {
      await _zonedSchedule(
        id: id,
        fireAt: fireAt,
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    try {
      final android = _android;
      if (android == null) return; // iOS / not applicable
      final allowed = await android.canScheduleExactNotifications() ?? false;
      if (!allowed) await android.requestExactAlarmsPermission();
    } catch (_) {}
  }

  @override
  Future<bool> canScheduleExact() async {
    final android = _android;
    if (android == null) return true; // iOS / not applicable
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBatteryOptimizationExempt() async {
    if (_android == null) return true; // iOS / not applicable
    try {
      return await _native
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestBatteryOptimizationExemption() async {
    if (_android == null) return; // iOS / not applicable
    try {
      await _native.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(soundName: soundName),
        payload: payload,
      );
    } catch (_) {}
  }

  @override
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {
    try {
      await _zonedSchedule(
        id: id,
        fireAt: fireAt,
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
      );
    } catch (_) {}
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _zonedSchedule(
        id: id,
        scheduledDate: _nextInstanceOf(weekday, hour, minute),
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  @override
  String get salatChannelId => _salatChannelId;

  @override
  Future<void> openNotificationSettings({String? channelId}) async {
    try {
      await _native.invokeMethod<void>(
        'openNotificationSettings',
        {'channelId': channelId},
      );
    } catch (_) {}
  }

  @override
  Future<String?> consumeLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  /// Schedules with EXACT alarms, falling back to inexact only if the platform
  /// actually REFUSES the exact alarm.
  ///
  /// It used to ask `canScheduleExactNotifications()` first and downgrade when
  /// that said no — but OxygenOS returns false from `canScheduleExactAlarms()`
  /// even with `USE_EXACT_ALARM` granted and `exactAllowReason=policy_permission`
  /// on the alarms it accepts. Trusting the gate meant every salat nudge was
  /// scheduled `setAndAllowWhileIdle`: `dumpsys alarm` showed `window=+1h0m0s0ms
  /// flags=0x8`, i.e. up to an hour late, batched, and posted in Doze without a
  /// sound. So: attempt exact, and let the plugin's own
  /// `ExactAlarmPermissionException` — not a pre-flight guess — be what
  /// downgrades us. Scheduling still never throws.
  bool _lastScheduleWasExact = true;

  @override
  bool get lastScheduleWasExact => _lastScheduleWasExact;

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    DateTime? fireAt,
    tz.TZDateTime? scheduledDate,
    String? payload,
    String? soundName,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final when = scheduledDate ?? tz.TZDateTime.from(fireAt!, tz.local);
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details(soundName: soundName),
          androidScheduleMode: mode,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );

    try {
      await schedule(AndroidScheduleMode.alarmClock);
      _lastScheduleWasExact = true;
    } on PlatformException {
      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
        _lastScheduleWasExact = true;
      } on PlatformException {
        _lastScheduleWasExact = false;
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    }
  }

  NotificationDetails _details({String? soundName}) {
    final salatSound = soundName == 'salat_nudge';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        salatSound ? _salatChannelId : _channelId,
        salatSound ? _salatChannelName : _channelName,
        channelDescription: salatSound ? _salatChannelDesc : _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: salatSound
            ? const RawResourceAndroidNotificationSound('salat_nudge')
            : null,
        enableVibration: true,
        vibrationPattern: salatSound ? _salatVibrationPattern : null,
        audioAttributesUsage: AudioAttributesUsage.notification,
        // Tag as a REMINDER so the OS (and aggressive OEM skins) treat it as a
        // time-sensitive nudge rather than a disposable alert.
        category: AndroidNotificationCategory.reminder,
        // Our OWN group, so the OS never force-bundles these into its
        // "Aggregate" autogroup. It only autogroups UNGROUPED notifications,
        // and once ours were bundled the children stopped alerting: a salat
        // notification posted exactly on time (verified) but completely
        // silent, because a lingering sound-check notification had already
        // triggered the bundle. GROUP_ALERT_ALL keeps every prayer audible.
        groupKey: salatSound ? _salatGroupKey : _sunnahGroupKey,
        groupAlertBehavior: GroupAlertBehavior.all,
        // Linger in the shade until the user swipes it away — a Sunnah nudge
        // shouldn't vanish on the next unlock (autoCancel defaults to true,
        // which clears it the moment it's tapped/brushed). Tapping still opens
        // the app via the payload route; it just no longer self-dismisses.
        autoCancel: false,
      ),
      iOS: DarwinNotificationDetails(
        sound: salatSound ? 'salat_nudge.wav' : null,
      ),
    );
  }

  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
}
