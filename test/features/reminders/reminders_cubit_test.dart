import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements NotificationScheduler {
  bool granted = true;
  int cancelAllCalls = 0;
  int weeklyCalls = 0;
  int testCalls = 0;
  final List<int> oneShotIds = [];

  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> cancelAll() async => cancelAllCalls++;
  @override
  Future<void> showTest({required String title, required String body}) async =>
      testCalls++;
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

  test('sendTestReminder shows a notification when permitted', () async {
    final sch = _FakeScheduler()..granted = true;
    await build(_FakeSettings(), sch).sendTestReminder();
    expect(sch.testCalls, 1);
  });

  test('sendTestReminder is a no-op when permission is denied', () async {
    final sch = _FakeScheduler()..granted = false;
    await build(_FakeSettings(), sch).sendTestReminder();
    expect(sch.testCalls, 0);
  });
}
