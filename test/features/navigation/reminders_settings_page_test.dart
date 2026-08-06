import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/navigation/presentation/pages/reminders_settings_page.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_notification_settings_repository.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'package:al_quran/features/reminders/domain/repositories/reminder_settings_repository.dart';
import 'package:al_quran/features/reminders/domain/scheduling/notification_scheduler.dart';
import 'package:al_quran/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38);
final _now = DateTime(2026, 6, 24, 10);

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  _FakeReminderSettingsRepository({this.enabled = false});
  @override
  bool enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _FakeScheduler implements NotificationScheduler {
  _FakeScheduler({this.granted = true, this.batteryExempt = true});
  bool granted;
  bool batteryExempt;
  int batteryExemptionCalls = 0;
  final List<String?> openedSettingsChannelIds = [];

  @override
  Future<void> init({void Function(String? payload)? onSelect}) async {}
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> requestExactAlarmPermission() async {}
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
  Future<void> cancel(int id) async {}
  @override
  Future<int> pendingCount() async => 0;
  @override
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async =>
      null;
  @override
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
    String? soundName,
  }) async {}
  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundName,
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
  @override
  Future<String?> consumeLaunchPayload() async => null;
  @override
  String get salatChannelId => 'salat_notifications_nature_v4';
  @override
  Future<void> openNotificationSettings({String? channelId}) async =>
      openedSettingsChannelIds.add(channelId);
}

class _FakePrayerNotificationSettingsRepository
    implements PrayerNotificationSettingsRepository {
  _FakePrayerNotificationSettingsRepository({this.enabled = false});
  @override
  bool enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _FakePrayerTimesRepository implements PrayerTimesRepository {
  _FakePrayerTimesRepository({
    this.saved,
    this.acquireStatus = LocationStatus.ok,
  });
  GeoLocation? saved;
  LocationStatus acquireStatus;

  @override
  GeoLocation? get location => saved;
  @override
  Future<LocationResult> acquireLocation() async {
    if (acquireStatus != LocationStatus.ok) {
      return LocationResult(acquireStatus, null);
    }
    saved = _loc;
    return const LocationResult(LocationStatus.ok, _loc);
  }

  @override
  DailyPrayerTimes? timesFor(GeoLocation location, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return DailyPrayerTimes(
      fajr: d.add(const Duration(hours: 5)),
      sunrise: d.add(const Duration(hours: 6, minutes: 30)),
      dhuhr: d.add(const Duration(hours: 12)),
      asr: d.add(const Duration(hours: 15, minutes: 30)),
      maghrib: d.add(const Duration(hours: 18, minutes: 42)),
      isha: d.add(const Duration(hours: 20)),
      location: location,
      date: d,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  RemindersCubit? reminders,
  PrayerNotificationsCubit? prayerNotifications,
  PrayerTimesCubit? prayerTimes,
}) {
  const page = MaterialApp(home: RemindersSettingsPage());
  final providers = [
    if (reminders != null) BlocProvider<RemindersCubit>.value(value: reminders),
    if (prayerNotifications != null)
      BlocProvider<PrayerNotificationsCubit>.value(
        value: prayerNotifications,
      ),
    if (prayerTimes != null)
      BlocProvider<PrayerTimesCubit>.value(value: prayerTimes),
  ];
  return tester.pumpWidget(
    providers.isEmpty
        ? page
        : MultiBlocProvider(providers: providers, child: page),
  );
}

void main() {
  group('RemindersSettingsPage', () {
    testWidgets('renders both rows with independent toggles', (tester) async {
      final reminders = RemindersCubit(
        _FakeReminderSettingsRepository(),
        _FakeScheduler(),
        clock: () => _now,
      );
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(),
        _FakeScheduler(),
        _FakePrayerTimesRepository(saved: _loc),
      );
      addTearDown(reminders.close);
      addTearDown(prayerNotifications.close);

      await _pump(
        tester,
        reminders: reminders,
        prayerNotifications: prayerNotifications,
      );

      expect(find.byKey(WidgetKeys.remindersPage), findsOneWidget);
      expect(find.text('Sunnah Reminders'), findsOneWidget);
      expect(find.text('Salat Notifications'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(find.byKey(WidgetKeys.sunnahRemindersToggle))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(WidgetKeys.prayerNotificationsToggle))
            .value,
        isFalse,
      );

      // Toggling one must not affect the other.
      await tester.tap(find.byKey(WidgetKeys.sunnahRemindersToggle));
      await tester.pumpAndSettle();
      expect(reminders.state.enabled, isTrue);
      expect(prayerNotifications.state.enabled, isFalse);
    });

    testWidgets('the info buttons open compact explanations without toggling',
        (tester) async {
      final reminders = RemindersCubit(
        _FakeReminderSettingsRepository(),
        _FakeScheduler(),
        clock: () => _now,
      );
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(),
        _FakeScheduler(),
        _FakePrayerTimesRepository(saved: _loc),
      );
      addTearDown(reminders.close);
      addTearDown(prayerNotifications.close);
      await _pump(
        tester,
        reminders: reminders,
        prayerNotifications: prayerNotifications,
      );

      await tester.tap(find.byKey(WidgetKeys.sunnahRemindersInfoButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Surah Al-Kahf'), findsOneWidget);
      expect(reminders.state.enabled, isFalse);
      expect(find.byType(PopupMenuItem<void>), findsNothing);

      // Dismiss like a tooltip — tap outside the popover, not a dialog button.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Surah Al-Kahf'), findsNothing);

      await tester.tap(find.byKey(WidgetKeys.prayerNotificationsInfoButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('daily prayer'), findsOneWidget);
      expect(prayerNotifications.state.enabled, isFalse);
    });

    testWidgets('shows the permission-denied hint instead of a silent revert',
        (tester) async {
      final reminders = RemindersCubit(
        _FakeReminderSettingsRepository(),
        _FakeScheduler(granted: false),
        clock: () => _now,
      );
      addTearDown(reminders.close);
      await _pump(tester, reminders: reminders);

      await tester.tap(find.byKey(WidgetKeys.sunnahRemindersToggle));
      await tester.pumpAndSettle();

      expect(reminders.state.enabled, isFalse);
      expect(find.textContaining('phone Settings'), findsOneWidget);
    });

    testWidgets(
        'Salat: shows the permission-denied hint instead of a silent revert',
        (tester) async {
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(),
        _FakeScheduler(granted: false),
        _FakePrayerTimesRepository(saved: _loc),
      );
      addTearDown(prayerNotifications.close);
      await _pump(tester, prayerNotifications: prayerNotifications);

      await tester.tap(find.byKey(WidgetKeys.prayerNotificationsToggle));
      await tester.pumpAndSettle();

      expect(prayerNotifications.state.enabled, isFalse);
      expect(find.textContaining('phone Settings'), findsOneWidget);
    });

    testWidgets('shows Up next + reliability hint only while enabled',
        (tester) async {
      final reminders = RemindersCubit(
        _FakeReminderSettingsRepository(enabled: true),
        _FakeScheduler(batteryExempt: false),
        clock: () => _now,
      );
      addTearDown(reminders.close);
      await reminders.refresh();
      await _pump(tester, reminders: reminders);
      await tester.pump();

      expect(find.text('Up next'), findsOneWidget);
      expect(find.textContaining('may delay reminders'), findsOneWidget);
    });

    testWidgets(
        'Salat: the debug "Schedule salat test" button schedules and reports',
        (tester) async {
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(enabled: true),
        _FakeScheduler(),
        _FakePrayerTimesRepository(saved: _loc),
      );
      addTearDown(prayerNotifications.close);
      await prayerNotifications.refresh();
      await _pump(tester, prayerNotifications: prayerNotifications);
      await tester.pump();

      expect(
        find.byKey(WidgetKeys.prayerNotificationsTestButton),
        findsOneWidget,
      );
      await tester.tap(find.byKey(WidgetKeys.prayerNotificationsTestButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scheduled'), findsOneWidget);
    });

    testWidgets(
        'Salat: enabling runs a sound check, and "No" opens the APP '
        'notification settings', (tester) async {
      final scheduler = _FakeScheduler();
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(),
        scheduler,
        _FakePrayerTimesRepository(saved: _loc),
      );
      addTearDown(prayerNotifications.close);
      await _pump(tester, prayerNotifications: prayerNotifications);

      await tester.tap(find.byKey(WidgetKeys.prayerNotificationsToggle));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Did you hear or feel it?'), findsOneWidget);

      await tester.tap(find.text("No, didn't notice"));
      await tester.pumpAndSettle();

      // Not the channel page: the Ring/Vibrate switches that silence
      // everything on ColorOS/OxygenOS live on the app page above it.
      expect(scheduler.openedSettingsChannelIds, [null]);
    });

    testWidgets(
        'shows a no-location hint for Salat when location is missing, '
        'and tapping it enables location and clears the hint', (tester) async {
      final repo = _FakePrayerTimesRepository(saved: null);
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(enabled: true),
        _FakeScheduler(),
        repo,
      );
      final prayerTimes = PrayerTimesCubit(repo, autoRefresh: false);
      addTearDown(prayerNotifications.close);
      addTearDown(prayerTimes.close);
      await prayerNotifications.refresh();
      await _pump(
        tester,
        prayerNotifications: prayerNotifications,
        prayerTimes: prayerTimes,
      );
      await tester.pump();

      expect(find.textContaining('Enable location'), findsOneWidget);

      await tester.tap(find.textContaining('Enable location'));
      await tester.pumpAndSettle();

      expect(repo.saved, isNotNull);
      expect(prayerNotifications.state.hasLocation, isTrue);
      expect(find.textContaining('Enable location'), findsNothing);
    });

    testWidgets(
        'tapping the no-location hint shows feedback instead of doing '
        'nothing when location permission is denied', (tester) async {
      final repo = _FakePrayerTimesRepository(
        saved: null,
        acquireStatus: LocationStatus.deniedForever,
      );
      final prayerNotifications = PrayerNotificationsCubit(
        _FakePrayerNotificationSettingsRepository(enabled: true),
        _FakeScheduler(),
        repo,
      );
      final prayerTimes = PrayerTimesCubit(repo, autoRefresh: false);
      addTearDown(prayerNotifications.close);
      addTearDown(prayerTimes.close);
      await prayerNotifications.refresh();
      await _pump(
        tester,
        prayerNotifications: prayerNotifications,
        prayerTimes: prayerTimes,
      );
      await tester.pump();

      await tester.tap(find.textContaining('Enable location'));
      await tester.pumpAndSettle();

      expect(repo.saved, isNull);
      expect(
        find.textContaining('Enable location for Al Quran'),
        findsOneWidget,
      );
      // The hint itself is unchanged (still there — no silent no-op).
      expect(find.textContaining('Enable location so'), findsOneWidget);
    });

    testWidgets('hides a reminder row entirely when its cubit is unavailable',
        (tester) async {
      await _pump(tester);
      expect(find.text('Sunnah Reminders'), findsNothing);
      expect(find.text('Salat Notifications'), findsNothing);
    });
  });
}
