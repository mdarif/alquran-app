import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/next_prayer_pill.dart';
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
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _pump(WidgetTester tester, PrayerTimesCubit? cubit) {
  const bar = Scaffold(appBar: null, body: Center(child: NextPrayerPill()));
  return tester.pumpWidget(
    MaterialApp(
      home: cubit == null
          ? bar
          : BlocProvider<PrayerTimesCubit>.value(value: cubit, child: bar),
    ),
  );
}

void main() {
  testWidgets('shows the next prayer + time when located', (tester) async {
    await _pump(tester, _cubit(saved: _loc, hour: 17)); // → Maghrib 18:42
    expect(find.byKey(WidgetKeys.nextPrayerPill), findsOneWidget);
    expect(find.textContaining('Maghrib'), findsOneWidget);
    expect(find.textContaining('6:42'), findsOneWidget);
  });

  testWidgets('during the dawn window the pill shows Sunrise', (tester) async {
    // Fake repo: fajr 5:00, sunrise 6:30 → at 06:00 the next marker is Sunrise.
    await _pump(tester, _cubit(saved: _loc, hour: 6));
    expect(find.textContaining('Sunrise'), findsOneWidget);
    expect(find.textContaining('6:30'), findsOneWidget);
  });

  testWidgets('tapping opens the all-five sheet', (tester) async {
    await _pump(tester, _cubit(saved: _loc, hour: 17));
    await tester.tap(find.byKey(WidgetKeys.nextPrayerPill));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsOneWidget);
    for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('6:30'), findsOneWidget); // sunrise time shown
    expect(find.textContaining('No prayer'), findsWidgets); // forbidden marks
    expect(find.textContaining('2026'), findsOneWidget); // Gregorian date line
  });

  testWidgets('inside a forbidden window the pill warns + tap opens sheet',
      (tester) async {
    // 18:30 is within the before-sunset window (18:27–18:42, lifts at Maghrib).
    await _pump(tester, _cubit(saved: _loc, hour: 18, minute: 30));
    expect(find.textContaining('Forbidden'), findsOneWidget);
    expect(find.textContaining('6:42'), findsOneWidget); // lifts at Maghrib

    await tester.tap(find.byKey(WidgetKeys.nextPrayerPill));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.prayerTimesSheet), findsOneWidget);
  });

  testWidgets('no location → a discreet enable affordance', (tester) async {
    await _pump(tester, _cubit(saved: null));
    expect(find.byKey(WidgetKeys.nextPrayerPill), findsOneWidget);
    expect(find.byIcon(Icons.location_searching_rounded), findsOneWidget);
  });

  testWidgets('renders nothing when no cubit is provided (defensive)',
      (tester) async {
    await _pump(tester, null);
    expect(find.byKey(WidgetKeys.nextPrayerPill), findsNothing);
  });
}
