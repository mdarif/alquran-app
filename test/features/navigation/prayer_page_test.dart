import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/features/navigation/presentation/pages/prayer_page.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
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
  Future<LocationResult> acquireLocation() async {
    saved = _loc;
    return const LocationResult(LocationStatus.ok, _loc);
  }

  @override
  Future<void> saveLocation(GeoLocation location) async => saved = location;

  @override
  Future<void> clearLocation() async => saved = null;

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

PrayerTimesCubit _cubit({GeoLocation? saved, int hour = 17, int minute = 0}) {
  final cubit = PrayerTimesCubit(
    _FakeRepo(saved: saved),
    clock: () => DateTime(2026, 6, 23, hour, minute),
    autoRefresh: false,
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _pump(WidgetTester tester, PrayerTimesCubit? cubit) {
  const page = Scaffold(body: PrayerPage());
  return tester.pumpWidget(
    MaterialApp(
      home: cubit == null
          ? page
          : BlocProvider<PrayerTimesCubit>.value(value: cubit, child: page),
    ),
  );
}

void main() {
  testWidgets('renders today\'s schedule without secondary settings',
      (tester) async {
    await _pump(tester, _cubit(saved: _loc, hour: 17));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.prayerPage), findsOneWidget);
    for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Sunrise'), findsNothing);
    expect(find.text('Reminders'), findsNothing);
  });

  testWidgets('keeps location picker legible without a city label',
      (tester) async {
    await _pump(tester, _cubit(saved: _loc, hour: 17));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.editLocation), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
  });

  testWidgets('no location → an enable-location affordance, no schedule',
      (tester) async {
    await _pump(tester, _cubit(saved: null));
    await tester.pumpAndSettle();

    expect(find.text('Enable location'), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
  });

  testWidgets('no cubit reachable (isolated pump) → a calm fallback, no crash',
      (tester) async {
    await _pump(tester, null);
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.prayerPage), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
  });
}
