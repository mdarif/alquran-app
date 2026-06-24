import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/location/location_provider.dart';
import 'package:al_quran/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:al_quran/features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/hijri_date_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// No saved location → the header falls back to the civil date (no sunset roll),
// which keeps the conversion deterministic from the injected clock.
class _NoLocRepo implements PrayerTimesRepository {
  @override
  GeoLocation? get location => null;
  @override
  Future<LocationResult> acquireLocation() async =>
      const LocationResult(LocationStatus.denied);
  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('shows the Hijri date over the weekday + Gregorian',
      (tester) async {
    final cubit =
        PrayerTimesCubit(_NoLocRepo(), clock: () => DateTime(2000, 1, 1, 10));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PrayerTimesCubit>.value(
            value: cubit,
            child: const HijriDateHeader(),
          ),
        ),
      ),
    );

    // 2000-01-01 (a Saturday) → 24 Ramadan 1420.
    expect(find.text('24 Ramadan 1420 AH'), findsOneWidget);
    expect(find.text('Saturday · 1 January 2000'), findsOneWidget);
  });

  testWidgets('renders without a prayer cubit (defensive)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HijriDateHeader())),
    );
    // Falls back to today's civil date — no provider, no throw.
    expect(find.byKey(WidgetKeys.hijriDateHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
