import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:al_quran/features/reminders/presentation/widgets/upcoming_reminders_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements NotificationScheduler {
  bool granted = true;
  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> cancelAll() async {}
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

Future<void> _pump(WidgetTester tester, RemindersCubit? cubit) {
  const section = Scaffold(body: UpcomingRemindersSection());
  return tester.pumpWidget(
    MaterialApp(
      home: cubit == null
          ? section
          : BlocProvider<RemindersCubit>.value(value: cubit, child: section),
    ),
  );
}

void main() {
  testWidgets('renders nothing without a cubit (defensive)', (tester) async {
    await _pump(tester, null);
    expect(find.byKey(WidgetKeys.enableRemindersCard), findsNothing);
    expect(find.byKey(WidgetKeys.upcomingRemindersSection), findsNothing);
  });

  testWidgets('shows the Enable card when disabled', (tester) async {
    final cubit = RemindersCubit(
      _FakeSettings(),
      _FakeScheduler(),
      clock: () => _now,
    );
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    expect(find.byKey(WidgetKeys.enableRemindersCard), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);
  });

  testWidgets('lists upcoming events when enabled', (tester) async {
    final cubit = RemindersCubit(
      _FakeSettings(enabled: true),
      _FakeScheduler()..granted = true,
      clock: () => _now,
    );
    addTearDown(cubit.close);
    await cubit.refresh(); // populates upcoming + permissionGranted
    await _pump(tester, cubit);
    await tester.pump();

    expect(find.byKey(WidgetKeys.upcomingRemindersSection), findsOneWidget);
    expect(find.textContaining('Al-Kahf'), findsWidgets); // the Al-Kahf row
    expect(find.textContaining('Ashura'), findsWidgets); // a fasting row
  });
}
