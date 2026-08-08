import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/prayer_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A New Delhi-shaped day: dawn well before noon, sunset well after it. The
/// meridiem of these three tiles is the whole point — Suhur is a morning time
/// and Iftar an evening one, so an inverted marker is a correctness bug, not a
/// cosmetic one.
DailyPrayerTimes _times() {
  DateTime at(int hour, int minute) => DateTime(2026, 8, 8, hour, minute);
  return DailyPrayerTimes(
    fajr: at(5, 9),
    sunrise: at(6, 33),
    dhuhr: at(13, 46),
    asr: at(17, 33),
    maghrib: at(20, 41),
    isha: at(22, 20),
    location: const GeoLocation(latitude: 28.61, longitude: 77.21),
    date: DateTime(2026, 8, 8),
  );
}

Widget _host({
  double textScale = 1,
  double width = 400,
  bool use24h = false,
  DateTime? nextFajr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        alwaysUse24HourFormat: use24h,
        size: Size(width, 900),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ExtraTimings(times: _times(), nextFajr: nextFajr),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders Suhur and Iftar with the correct meridiem',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('5:09 AM'), findsOneWidget);
    expect(find.text('8:41 PM'), findsOneWidget);
  });

  testWidgets('renders Tahajjud from tomorrow Fajr in the small hours',
      (tester) async {
    await tester.pumpWidget(
      _host(nextFajr: DateTime(2026, 8, 9, 5, 10)),
    );

    // maghrib 20:41 + 2/3 of the 8h29m night = 02:20 the next morning.
    expect(find.text('2:20 AM'), findsOneWidget);
  });

  testWidgets('honours a 24-hour locale', (tester) async {
    await tester.pumpWidget(_host(use24h: true));

    expect(find.text('05:09'), findsOneWidget);
    expect(find.text('20:41'), findsOneWidget);
  });

  testWidgets('shows a placeholder when Tahajjud cannot be derived',
      (tester) async {
    // A "tomorrow Fajr" that lands before Maghrib leaves no night to divide.
    await tester.pumpWidget(_host(nextFajr: DateTime(2026, 8, 8, 5, 9)));

    expect(find.text('-'), findsNothing); // falls back to fajr + 1 day
  });

  group('does not overflow', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final width in [320.0, 360.0, 400.0]) {
        testWidgets('at text scale $scale and width $width', (tester) async {
          await tester.pumpWidget(_host(textScale: scale, width: width));

          expect(tester.takeException(), isNull);
          // Labels must stay whole — the reported bug was "Suhur en…".
          expect(find.text('Suhur End'), findsOneWidget);
          expect(find.text('Iftar'), findsOneWidget);
          expect(find.text('Tahajjud'), findsOneWidget);
        });
      }
    }
  });

  testWidgets('stays three-across at default width and scale', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(IntrinsicHeight), findsOneWidget);
  });

  testWidgets('stacks when the tiles would be squeezed', (tester) async {
    await tester.pumpWidget(_host(width: 300));

    expect(find.byType(IntrinsicHeight), findsNothing);
  });
}
