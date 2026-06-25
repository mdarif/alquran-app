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

Future<void> _pumpSheet(WidgetTester tester, {required DateTime base}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrayerTimesSheet(
          times: _day(),
          next: Prayer.asr,
          hijriBaseDate: base,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the title-cased heading', (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(find.text('Prayer Times'), findsOneWidget);
  });

  testWidgets('shows the Hijri over the Gregorian date', (tester) async {
    // 2000-01-01 → 24 Ramadan 1420 (the converter anchor).
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(find.text('24 Ramadan 1420 AH'), findsOneWidget);
    expect(find.text('1 January 2000'), findsOneWidget);
  });

  testWidgets('lists the five prayers plus Sunrise with their times',
      (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    for (final label in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(label), findsOneWidget);
    }
    // 12-hour, no AM/PM (the names disambiguate): Fajr 5:00, Asr 15:00 → 3:00.
    expect(find.text('5:00'), findsOneWidget); // Fajr
    expect(find.text('3:00'), findsOneWidget); // Asr
    expect(find.text('7:00'), findsOneWidget); // Isha
  });

  testWidgets('emphasises the next prayer (bold) and not the others',
      (tester) async {
    // _pumpSheet marks Asr as next.
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(
      tester.widget<Text>(find.text('Asr')).style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('3:00')).style?.fontWeight, // Asr's time
      FontWeight.w700,
    );
    // A non-next salah stays at the regular weight.
    expect(
      tester.widget<Text>(find.text('Fajr')).style?.fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('shows the three tightened "no prayer" window captions',
      (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    // afterSunrise 6:30–6:45, zenith 11:55–12:00, beforeSunset 5:15–5:30.
    expect(find.textContaining('No prayer'), findsNWidgets(3));
    expect(find.textContaining('No prayer · 6:30'), findsOneWidget);
    expect(find.textContaining('No prayer · 11:55'), findsOneWidget);
    expect(find.textContaining('No prayer · 5:15'), findsOneWidget);
  });
}
