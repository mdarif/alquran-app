import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:al_quran/features/reminders/presentation/widgets/reminders_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements NotificationScheduler {
  bool granted = true;
  bool batteryExempt = true;
  int batteryExemptionCalls = 0;
  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> requestExactAlarmPermission() async {}
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
  Future<int> pendingCount() async => 0;
  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
  }) async =>
      null;
  @override
  Future<String?> consumeLaunchPayload() async => null;
  @override
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
  }) async {}
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
}

class _FakeSettings implements ReminderSettingsRepository {
  _FakeSettings({this.enabled = false});
  @override
  bool enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

final _now = DateTime(2026, 6, 24, 10); // 8 Muharram 1448

Future<void> _pump(WidgetTester tester, RemindersCubit cubit) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<RemindersCubit>.value(
          value: cubit,
          child: const RemindersSheet(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('disabled: toggle off, no up-next list', (tester) async {
    final cubit = RemindersCubit(
      _FakeSettings(),
      _FakeScheduler(),
      clock: () => _now,
    );
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    expect(find.byKey(WidgetKeys.remindersSheet), findsOneWidget);
    expect(find.text('Up next'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('enabled: shows the up-next list', (tester) async {
    final cubit = RemindersCubit(
      _FakeSettings(enabled: true),
      _FakeScheduler()..granted = true,
      clock: () => _now,
    );
    addTearDown(cubit.close);
    await cubit.refresh();
    await _pump(tester, cubit);
    await tester.pump();

    expect(find.text('Up next'), findsOneWidget);
    expect(find.textContaining('Al-Kahf'), findsWidgets);
  });

  testWidgets('battery-optimized: shows the reliability hint, tap re-prompts',
      (tester) async {
    final sch = _FakeScheduler()
      ..granted = true
      ..batteryExempt = false; // not exempt → hint appears
    final cubit = RemindersCubit(
      _FakeSettings(enabled: true),
      sch,
      clock: () => _now,
    );
    addTearDown(cubit.close);
    await cubit.refresh();
    await _pump(tester, cubit);
    await tester.pump();

    final hint = find.textContaining('may delay reminders');
    expect(hint, findsOneWidget);

    await tester.tap(hint);
    await tester.pump();
    expect(sch.batteryExemptionCalls, 1);
  });
}
