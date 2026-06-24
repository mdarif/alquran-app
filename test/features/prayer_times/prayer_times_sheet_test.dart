import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/entities/prayer.dart';
import 'package:al_quran/features/prayer_times/presentation/widgets/prayer_times_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DailyPrayerTimes _day() {
  final d = DateTime(2000, 1, 1);
  DateTime t(int h, [int m = 0]) => d.add(Duration(hours: h, minutes: m));
  return DailyPrayerTimes(
    fajr: t(5),
    sunrise: t(6, 30),
    dhuhr: t(12),
    asr: t(15),
    maghrib: t(17, 30),
    isha: t(19),
    location: const GeoLocation(latitude: 24.45, longitude: 54.38),
    date: d,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required DateTime base,
  int adjustment = 0,
  ValueChanged<int>? onAdjust,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrayerTimesSheet(
          times: _day(),
          next: Prayer.asr,
          hijriBaseDate: base,
          hijriAdjustment: adjustment,
          onAdjustHijri: onAdjust,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the Hijri (Urdu) over the Gregorian date', (tester) async {
    // 2000-01-01 → 24 Ramadan 1420 (the converter anchor).
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(find.text('۲۴ رمضان ۱۴۲۰ھ'), findsOneWidget);
    expect(find.text('1 January 2000'), findsOneWidget);
  });

  testWidgets('the ± control nudges the Hijri day and persists it',
      (tester) async {
    int? reported;
    await _pumpSheet(
      tester,
      base: DateTime(2000, 1, 1),
      onAdjust: (v) => reported = v,
    );

    await tester.tap(find.byTooltip('Hijri +1 day (moon sighting)'));
    await tester.pumpAndSettle();

    expect(find.text('۲۵ رمضان ۱۴۲۰ھ'), findsOneWidget); // advanced one day
    expect(reported, 1);
  });

  testWidgets('no ± control when adjustment is not wired', (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1)); // onAdjust null
    expect(find.byTooltip('Hijri +1 day (moon sighting)'), findsNothing);
  });
}
