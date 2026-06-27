import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements NotificationScheduler {
  bool granted = true;
  bool batteryExempt = true;
  int cancelAllCalls = 0;
  int weeklyCalls = 0;
  int exactAlarmCalls = 0;
  int batteryExemptionCalls = 0;
  final List<int> oneShotIds = [];

  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> requestExactAlarmPermission() async => exactAlarmCalls++;
  @override
  Future<bool> canScheduleExact() async => true;
  @override
  Future<bool> isBatteryOptimizationExempt() async => batteryExempt;
  @override
  Future<void> requestBatteryOptimizationExemption() async =>
      batteryExemptionCalls++;
  @override
  Future<void> cancelAll() async => cancelAllCalls++;
  @override
  Future<int> pendingCount() async => oneShotIds.length;
  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {
    oneShotIds.add(id);
    return null;
  }

  @override
  Future<String?> consumeLaunchPayload() async => null;

  @override
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
  }) async =>
      oneShotIds.add(id);

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async =>
      weeklyCalls++;
}

class _FakeSettings implements ReminderSettingsRepository {
  _FakeSettings({this.enabled = false});
  @override
  bool enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

void main() {
  final now = DateTime(2026, 6, 24, 10); // 8 Muharram 1448

  RemindersCubit build(_FakeSettings s, _FakeScheduler sch) {
    final c = RemindersCubit(s, sch, clock: () => now);
    addTearDown(c.close);
    return c;
  }

  test('enable (granted) persists, cancels, schedules window + 1 weekly',
      () async {
    final s = _FakeSettings();
    final sch = _FakeScheduler()..granted = true;
    final c = build(s, sch);

    await c.enable();

    expect(s.enabled, isTrue);
    expect(sch.cancelAllCalls, 1);
    expect(sch.weeklyCalls, 1); // Al-Kahf weekly
    expect(sch.oneShotIds, isNotEmpty); // Ashura + Ayyam al-Bid one-shots
    expect(c.state.enabled, isTrue);
    expect(c.state.permissionGranted, isTrue);
    expect(c.state.upcoming, isNotEmpty);
  });

  test('Al-Kahf is scheduled weekly, never as a one-shot', () async {
    final sch = _FakeScheduler()..granted = true;
    await build(_FakeSettings(), sch).enable();
    expect(sch.oneShotIds.any((id) => id >= 1000 && id < 2000), isFalse);
  });

  test('enable (denied) flags permission off and schedules nothing', () async {
    final s = _FakeSettings();
    final sch = _FakeScheduler()..granted = false;
    final c = build(s, sch);

    await c.enable();

    expect(s.enabled, isFalse);
    expect(sch.cancelAllCalls, 0);
    expect(sch.weeklyCalls, 0);
    expect(c.state.permissionGranted, isFalse);
  });

  test('refresh while enabled + permitted reschedules the window', () async {
    final sch = _FakeScheduler()..granted = true;
    final c = build(_FakeSettings(enabled: true), sch);

    await c.refresh();

    expect(sch.cancelAllCalls, 1);
    expect(sch.weeklyCalls, 1);
    expect(c.state.upcoming, isNotEmpty);
  });

  test('refresh while disabled clears state', () async {
    final c = build(_FakeSettings(), _FakeScheduler());
    await c.refresh();
    expect(c.state.enabled, isFalse);
    expect(c.state.upcoming, isEmpty);
  });

  test('disable cancels everything and clears', () async {
    final s = _FakeSettings(enabled: true);
    final sch = _FakeScheduler()..granted = true;
    final c = build(s, sch);

    await c.disable();

    expect(s.enabled, isFalse);
    expect(sch.cancelAllCalls, 1);
    expect(c.state.enabled, isFalse);
    expect(c.state.upcoming, isEmpty);
  });

  test('initial state reflects persisted enabled with a computed list', () {
    final c = build(_FakeSettings(enabled: true), _FakeScheduler());
    expect(c.state.enabled, isTrue);
    expect(c.state.upcoming, isNotEmpty);
  });

  test('enable nudges toward reliable delivery (exact alarms + exemption)',
      () async {
    final sch = _FakeScheduler()
      ..granted = true
      ..batteryExempt = false; // not yet exempt → should be prompted
    await build(_FakeSettings(), sch).enable();
    expect(sch.exactAlarmCalls, 1);
    expect(sch.batteryExemptionCalls, 1);
  });

  test('enable skips the exemption prompt when already exempt', () async {
    final sch = _FakeScheduler()
      ..granted = true
      ..batteryExempt = true;
    await build(_FakeSettings(), sch).enable();
    expect(sch.exactAlarmCalls, 1);
    expect(sch.batteryExemptionCalls, 0);
  });

  test('refresh surfaces the battery-optimization reliability flag', () async {
    final sch = _FakeScheduler()
      ..granted = true
      ..batteryExempt = false;
    final c = build(_FakeSettings(enabled: true), sch);
    await c.refresh();
    expect(c.state.batteryOptimized, isTrue);
  });

  test('fixReliability re-runs the exemption prompt', () async {
    final sch = _FakeScheduler()..granted = true;
    await build(_FakeSettings(enabled: true), sch).fixReliability();
    expect(sch.batteryExemptionCalls, 1);
  });

  test('scheduleDeliveryTest queues a one-shot and reports success', () async {
    final sch = _FakeScheduler()..granted = true;
    final report =
        await build(_FakeSettings(enabled: true), sch).scheduleDeliveryTest();
    expect(sch.oneShotIds, contains(99));
    expect(report, contains('Scheduled'));
  });
}
