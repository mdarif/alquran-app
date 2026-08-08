import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/entities/prayer.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/domain/scheduling/prayer_notification_payload.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38);

class _FakePrayerRepo implements PrayerTimesRepository {
  _FakePrayerRepo({this.saved});

  GeoLocation? saved;

  @override
  GeoLocation? get location => saved;

  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.ok, _loc);

  @override
  Future<void> saveLocation(GeoLocation location) async {}

  @override
  Future<void> clearLocation() async {}

  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return DailyPrayerTimes(
      fajr: d.add(const Duration(hours: 5, minutes: 3)),
      sunrise: d.add(const Duration(hours: 6, minutes: 45)),
      dhuhr: d.add(const Duration(hours: 13, minutes: 47)),
      asr: d.add(const Duration(hours: 17, minutes: 35)),
      maghrib: d.add(const Duration(hours: 20, minutes: 46)),
      isha: d.add(const Duration(hours: 22, minutes: 28)),
      location: location,
      date: d,
    );
  }
}

class _FakeSettings implements PrayerNotificationSettingsRepository {
  _FakeSettings({this.enabled = false});

  @override
  bool enabled;

  @override
  bool allowZoneMismatchAlerts = false;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<void> setAllowZoneMismatchAlerts(bool value) async =>
      allowZoneMismatchAlerts = value;
}

class _Scheduled {
  const _Scheduled({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    this.payload,
    this.soundName,
  });

  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
  final String? payload;
  final String? soundName;
}

class _FakeScheduler implements NotificationScheduler {
  bool granted = true;
  bool batteryExempt = true;
  int requestPermissionCalls = 0;
  int exactAlarmCalls = 0;
  int batteryExemptionCalls = 0;
  final List<int> cancelledIds = [];
  final List<_Scheduled> oneShots = [];
  final List<_Scheduled> shownNow = [];
  final List<String?> openedSettingsChannelIds = [];

  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> requestExactAlarmPermission() async => exactAlarmCalls++;

  @override
  bool lastScheduleWasExact = true;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<bool> isBatteryOptimizationExempt() async => batteryExempt;

  @override
  Future<void> requestBatteryOptimizationExemption() async =>
      batteryExemptionCalls++;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancel(int id) async => cancelledIds.add(id);

  @override
  Future<int> pendingCount() async => oneShots.length;

  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {
    oneShots.add(
      _Scheduled(
        id: id,
        fireAt: fireAt,
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
      ),
    );
    return null;
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
    oneShots.add(
      _Scheduled(
        id: id,
        fireAt: fireAt,
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
      ),
    );
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {
    shownNow.add(
      _Scheduled(
        id: id,
        fireAt: DateTime(0),
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
      ),
    );
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
  }) async {}

  @override
  Future<String?> consumeLaunchPayload() async => null;

  @override
  String get salatChannelId => 'salat_notifications_nature_v4';

  @override
  Future<void> openNotificationSettings({String? channelId}) async =>
      openedSettingsChannelIds.add(channelId);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final now = DateTime(2026, 8, 3, 12);

  PrayerNotificationsCubit build({
    _FakeSettings? settings,
    _FakeScheduler? scheduler,
    _FakePrayerRepo? repo,
    DateTime Function()? clock,
  }) {
    final cubit = PrayerNotificationsCubit(
      settings ?? _FakeSettings(),
      scheduler ?? _FakeScheduler(),
      repo ?? _FakePrayerRepo(saved: _loc),
      clock: clock ?? () => now,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('enable requests permission, persists, and schedules salah only',
      () async {
    final settings = _FakeSettings();
    final scheduler = _FakeScheduler();
    final cubit = build(settings: settings, scheduler: scheduler);

    await cubit.enable();

    expect(settings.enabled, isTrue);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.permissionGranted, isTrue);
    expect(scheduler.oneShots, hasLength(9));
    expect(
      scheduler.oneShots.map((n) => n.title).toList(),
      everyElement(startsWith('Salat Time - ')),
    );
    expect(
      scheduler.oneShots.map((n) => n.title),
      isNot(contains('Salat Time - Sunrise')),
    );
    expect(
      scheduler.oneShots.map((n) => n.soundName),
      everyElement('salat_nudge'),
    );
    expect(
      scheduler.oneShots.map((n) => n.payload),
      everyElement(startsWith('open:prayer_times?')),
    );
    final asrPayload = scheduler.oneShots
        .firstWhere(
          (n) => n.title == 'Salat Time - Asr',
        )
        .payload;
    final tap = parsePrayerTimesPayload(asrPayload);
    expect(tap?.prayer, Prayer.asr);
    expect(tap?.fireAt, DateTime(2026, 8, 3, 17, 35));
  });

  test('timezone mismatch pauses alerts until explicitly overridden', () async {
    final settings = _FakeSettings();
    final scheduler = _FakeScheduler();
    final cubit = build(
      settings: settings,
      scheduler: scheduler,
      repo: _FakePrayerRepo(
        saved: const GeoLocation(
          latitude: 40.7128,
          longitude: -74.006,
          timezoneId: 'America/New_York',
        ),
      ),
    );

    await cubit.enable();

    expect(cubit.state.zoneMismatch, isTrue);
    expect(scheduler.oneShots, isEmpty);

    await cubit.turnOnAnyway();

    expect(settings.allowZoneMismatchAlerts, isTrue);
    expect(cubit.state.zoneMismatch, isFalse);
    expect(scheduler.oneShots, isNotEmpty);
  });

  test('notification copy uses prayer name and formatted time', () async {
    final scheduler = _FakeScheduler();
    await build(scheduler: scheduler).enable();

    final isha = scheduler.oneShots.firstWhere(
      (n) => n.fireAt == DateTime(2026, 8, 3, 22, 28),
    );

    expect(isha.title, 'Salat Time - Isha');
    expect(isha.body, '10:28 PM');
  });

  test('refresh schedules only upcoming times across today and tomorrow',
      () async {
    final scheduler = _FakeScheduler();
    await build(
      settings: _FakeSettings(enabled: true),
      scheduler: scheduler,
      clock: () => DateTime(2026, 8, 3, 21),
    ).refresh();

    expect(scheduler.oneShots.map((n) => n.fireAt), [
      DateTime(2026, 8, 3, 22, 28),
      DateTime(2026, 8, 4, 5, 3),
      DateTime(2026, 8, 4, 13, 47),
      DateTime(2026, 8, 4, 17, 35),
      DateTime(2026, 8, 4, 20, 46),
      DateTime(2026, 8, 4, 22, 28),
    ]);
  });

  test('enable denied leaves setting off and schedules nothing', () async {
    final settings = _FakeSettings();
    final scheduler = _FakeScheduler()..granted = false;
    final cubit = build(settings: settings, scheduler: scheduler);

    await cubit.enable();

    expect(settings.enabled, isFalse);
    expect(cubit.state.permissionGranted, isFalse);
    expect(scheduler.oneShots, isEmpty);
  });

  test('refresh with no saved location does not schedule', () async {
    final scheduler = _FakeScheduler();

    await build(
      settings: _FakeSettings(enabled: true),
      scheduler: scheduler,
      repo: _FakePrayerRepo(),
    ).refresh();

    expect(scheduler.oneShots, isEmpty);
  });

  test('disable cancels only the prayer notification id range', () async {
    final settings = _FakeSettings(enabled: true);
    final scheduler = _FakeScheduler();
    final cubit = build(settings: settings, scheduler: scheduler);

    await cubit.disable();

    expect(settings.enabled, isFalse);
    expect(cubit.state.enabled, isFalse);
    expect(scheduler.cancelledIds, PrayerNotificationsCubit.notificationIds);
  });

  test('scheduleDeliveryTest queues a salat notification and reports success',
      () async {
    final scheduler = _FakeScheduler();

    final report = await build(scheduler: scheduler).scheduleDeliveryTest();

    // `now` is noon: 2 min later (12:02 PM) sits closest to Dhuhr (13:47),
    // NOT a fixed "Isha" — regression guard for the bug where the debug test
    // always said Isha regardless of the actual time of day.
    expect(report, contains('Scheduled'));
    expect(scheduler.oneShots.single.id, PrayerNotificationsCubit.debugTestId);
    expect(scheduler.oneShots.single.title, 'Salat Time - Dhuhr');
    expect(scheduler.oneShots.single.body, '12:02 PM');
    expect(scheduler.oneShots.single.soundName, 'salat_nudge');
    final tap = parsePrayerTimesPayload(scheduler.oneShots.single.payload);
    expect(tap?.prayer, Prayer.dhuhr);
    expect(tap?.fireAt, DateTime(2026, 8, 3, 12, 2));
  });

  test('scheduleDeliveryTest labels itself by whichever prayer is nearest',
      () async {
    // now = 17:33, 2 min later = 17:35 = exactly Asr — must say Asr, not
    // whatever the previous or next salah happens to be.
    final scheduler = _FakeScheduler();

    final report = await build(
      scheduler: scheduler,
      clock: () => DateTime(2026, 8, 3, 17, 33),
    ).scheduleDeliveryTest();

    expect(report, contains('Scheduled'));
    expect(scheduler.oneShots.single.title, 'Salat Time - Asr');
  });

  test('scheduleDeliveryTest requests permission when notifications are off',
      () async {
    final scheduler = _FakeScheduler()..granted = false;

    final report = await build(scheduler: scheduler).scheduleDeliveryTest();

    expect(scheduler.requestPermissionCalls, 1);
    expect(scheduler.oneShots, isEmpty);
    expect(report, contains('Notifications not allowed'));
  });

  test('enable nudges toward reliable delivery (exact alarms + exemption)',
      () async {
    final scheduler = _FakeScheduler()..batteryExempt = false;

    await build(scheduler: scheduler).enable();

    expect(scheduler.exactAlarmCalls, 1);
    expect(scheduler.batteryExemptionCalls, 1);
  });

  test('enable skips the exemption prompt when already exempt', () async {
    final scheduler = _FakeScheduler()..batteryExempt = true;

    await build(scheduler: scheduler).enable();

    expect(scheduler.exactAlarmCalls, 1);
    expect(scheduler.batteryExemptionCalls, 0);
  });

  test('refresh surfaces the battery-optimization reliability flag', () async {
    final scheduler = _FakeScheduler()..batteryExempt = false;
    final cubit = build(
      settings: _FakeSettings(enabled: true),
      scheduler: scheduler,
    );

    await cubit.refresh();

    expect(cubit.state.batteryOptimized, isTrue);
  });

  test('fixReliability re-runs the exemption prompt', () async {
    final scheduler = _FakeScheduler();

    await build(
      settings: _FakeSettings(enabled: true),
      scheduler: scheduler,
    ).fixReliability();

    expect(scheduler.batteryExemptionCalls, 1);
  });

  test('fixExactAlarms re-runs the exact-alarm prompt', () async {
    final scheduler = _FakeScheduler();

    await build(
      settings: _FakeSettings(enabled: true),
      scheduler: scheduler,
    ).fixExactAlarms();

    expect(scheduler.exactAlarmCalls, 1);
  });

  test('sendSoundCheck posts immediately, NOT through the alarm path',
      () async {
    final scheduler = _FakeScheduler();
    final cubit = build(scheduler: scheduler);

    await cubit.sendSoundCheck();

    // Regression: the check used to be scheduled "3 seconds out" via
    // AlarmManager, which the OS batches — so the "did you hear it?" prompt
    // asked about a notification that hadn't been posted yet.
    expect(scheduler.oneShots, isEmpty);
    expect(scheduler.shownNow, hasLength(1));
    final shown = scheduler.shownNow.single;
    expect(shown.id, PrayerNotificationsCubit.soundCheckId);
    expect(shown.soundName, 'salat_nudge');
  });

  test('notificationIds covers the sound-check and delivery-test ids', () {
    // Salat notifications are autoCancel:false, so any id NOT cancelled on
    // reschedule/disable lingers in the shade forever and gets the app
    // auto-bundled by the OS (which then drops the alert).
    expect(
      PrayerNotificationsCubit.notificationIds,
      containsAll([
        PrayerNotificationsCubit.soundCheckId,
        PrayerNotificationsCubit.debugTestId,
      ]),
    );
  });

  test('openSoundSettings opens the APP settings, not the channel page',
      () async {
    final scheduler = _FakeScheduler();
    final cubit = build(scheduler: scheduler);

    await cubit.openSoundSettings();

    // Regression: this used to deep-link to the Salat channel. On
    // ColorOS/OxygenOS the Ring/Vibrate switches that actually silence
    // everything live on the APP page — the channel page can't show them, so
    // "No, didn't notice" led users to a dead end.
    expect(scheduler.openedSettingsChannelIds, [null]);
  });
}
