import 'package:al_quran/app_navigator.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/domain/scheduling/prayer_notification_payload.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/prayer_times_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _loc = GeoLocation(latitude: 24.45, longitude: 54.38);

class _FakeRepo implements PrayerTimesRepository {
  _FakeRepo({this.saved});
  GeoLocation? saved;

  @override
  GeoLocation? get location => saved;
  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.ok, _loc);

  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) {
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

Future<void> _route(
  WidgetTester tester,
  PrayerTimesCubit? cubit,
  String? payload,
) async {
  final app = MaterialApp(
    navigatorKey: navigatorKey,
    home: const Scaffold(body: SizedBox()),
  );
  await tester.pumpWidget(
    cubit == null
        ? app
        : BlocProvider<PrayerTimesCubit>.value(value: cubit, child: app),
  );
  await routeFromPayload(payload);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a tapped salat notification opens the Prayer Times sheet '
      'when location + times are available', (tester) async {
    final cubit = PrayerTimesCubit(
      _FakeRepo(saved: _loc),
      clock: () => DateTime(2026, 6, 23, 17),
      autoRefresh: false,
    );
    addTearDown(cubit.close);

    await _route(tester, cubit, openPrayerTimesPayload);

    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsOneWidget);
    expect(find.byType(PrayerTimesSheet), findsOneWidget);
  });

  testWidgets(
      'no-op when the cubit has no location yet (nothing to show, no crash)',
      (tester) async {
    final cubit = PrayerTimesCubit(
      _FakeRepo(saved: null),
      clock: () => DateTime(2026, 6, 23, 17),
      autoRefresh: false,
    );
    addTearDown(cubit.close);

    await _route(tester, cubit, openPrayerTimesPayload);

    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsNothing);
  });

  testWidgets('no-op when no PrayerTimesCubit is reachable at all',
      (tester) async {
    await _route(tester, null, openPrayerTimesPayload);
    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsNothing);
  });

  testWidgets('an unrelated payload does not open the sheet', (tester) async {
    final cubit = PrayerTimesCubit(
      _FakeRepo(saved: _loc),
      clock: () => DateTime(2026, 6, 23, 17),
      autoRefresh: false,
    );
    addTearDown(cubit.close);

    await _route(tester, cubit, 'open:something-unrelated');

    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsNothing);
  });
}
