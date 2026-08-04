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

DailyPrayerTimes _newDelhiLikeDay() {
  final d = DateTime(2026, 8, 4);
  DateTime t(int h, [int m = 0]) => d.add(Duration(hours: h, minutes: m));
  return DailyPrayerTimes(
    fajr: t(4, 17),
    sunrise: t(5, 44),
    dhuhr: t(12, 28),
    asr: t(16, 1),
    maghrib: t(19, 10),
    isha: t(20, 36),
    location: const GeoLocation(
      latitude: 28.61,
      longitude: 77.21,
      label: 'New Delhi',
    ),
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
          initialNow: DateTime(2000, 1, 1, 13),
          liveCountdown: false,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the title-cased heading', (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(find.text("Today's Prayer Times"), findsOneWidget);
  });

  testWidgets('shows the Hijri over the Gregorian date', (tester) async {
    // 2000-01-01 → 24 Ramadan 1420 (the converter anchor).
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(find.text('24 Ramadan 1420 AH'), findsOneWidget);
    expect(find.text('1 January 2000'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('1 January 2000')).textAlign,
      TextAlign.end,
    );
  });

  testWidgets('lists the five prayers plus Sunrise with their times',
      (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    const labels = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final label in labels) {
      expect(find.text(label), findsWidgets);
    }
    // 12-hour, no AM/PM (the names disambiguate): Fajr 5:00, Asr 15:00 → 3:00.
    expect(find.text('5:00'), findsOneWidget); // Fajr
    expect(find.text('3:00'), findsWidgets); // Asr
    expect(find.text('7:00'), findsOneWidget); // Isha
  });

  testWidgets('emphasises the next prayer (bold) and not the others',
      (tester) async {
    // _pumpSheet marks Asr as next.
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    expect(
      find.text('Asr'),
      findsWidgets,
    );
    // A non-next salah stays at the regular weight.
    expect(
      tester.widget<Text>(find.text('Fajr')).style?.fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('shows the three tightened prohibited-time window captions',
      (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    // afterSunrise 6:30–6:45, zenith 11:55–12:00, beforeSunset 5:15–5:30.
    expect(find.textContaining('No Nafl Prayer · 6:30–6:45'), findsOneWidget);
    expect(find.textContaining('No Nafl Prayer · 11:55–12:00'), findsOneWidget);
    expect(find.textContaining('No Nafl Prayer · 5:15–5:30'), findsOneWidget);
  });

  testWidgets('shows current-to-next countdown context', (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Next'), findsWidgets);
    expect(find.text('02:00:00'), findsOneWidget);
  });

  testWidgets('keeps the next endpoint visually quieter than current',
      (tester) async {
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));

    final dhuhr = tester.widgetList<Text>(find.text('Dhuhr')).first;
    final asr = tester.widgetList<Text>(find.text('Asr')).first;
    expect(dhuhr.style?.fontWeight, FontWeight.w700);
    expect(asr.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('uses the next salah, not Sunrise, as the next endpoint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _day(),
            next: Prayer.fajr,
            initialNow: DateTime(2000, 1, 1, 5),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Fajr'), findsWidgets);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Sunrise'), findsWidgets);
    expect(find.text('07:00:00'), findsOneWidget);
  });

  testWidgets('shows next-prayer-only card when no salah is active',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _day(),
            next: Prayer.dhuhr,
            initialNow: DateTime(2000, 1, 1, 6, 50),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('Current'), findsNothing);
    expect(find.text('Next Prayer'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('05:10:00'), findsOneWidget);
  });

  testWidgets('skips the active salah when passed next is stale',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _day(),
            next: Prayer.dhuhr,
            initialNow: DateTime(2000, 1, 1, 12),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Asr'), findsWidgets);
    expect(find.text('03:00:00'), findsOneWidget);
    expect(find.text('Next'), findsWidgets);
  });

  testWidgets('shows Asr current and Maghrib next in the afternoon',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _newDelhiLikeDay(),
            next: Prayer.dhuhr,
            initialNow: DateTime(2026, 8, 4, 17, 43),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Asr'), findsWidgets);
    expect(find.text('Maghrib'), findsWidgets);
    expect(find.text('01:27:00'), findsOneWidget);
  });

  testWidgets('uses a distinct forbidden-time top card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _day(),
            next: Prayer.dhuhr,
            initialNow: DateTime(2000, 1, 1, 11, 58),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('No voluntary prayer'), findsOneWidget);
    expect(find.text('Zenith (Istiwāʾ)'), findsOneWidget);
    expect(find.text('Until 12:00'), findsOneWidget);
    expect(find.text('00:02:00'), findsOneWidget);
  });

  testWidgets('marks a tapped notification prayer separately from next',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrayerTimesSheet(
            times: _day(),
            next: Prayer.maghrib,
            notificationPrayer: Prayer.asr,
            notificationFireAt: DateTime(2000, 1, 1, 15),
            initialNow: DateTime(2000, 1, 1, 16),
            liveCountdown: false,
          ),
        ),
      ),
    );

    expect(find.text('Notified now'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Next'), findsWidgets);
    expect(find.text('01:30:00'), findsOneWidget);
  });

  testWidgets('gilds the Hijri date on a Sunnah occasion', (tester) async {
    // 2026-06-25 is 9 Muharram → Ashura. The bare test theme carries no
    // MushafColors extension, so the gild falls back to the default gold.
    await _pumpSheet(tester, base: DateTime(2026, 6, 25));
    final hijri = tester.widget<Text>(find.text('09 Muharram 1448 AH'));
    expect(hijri.style?.color, const Color(0xFF9C6F02));
    expect(hijri.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('leaves the Hijri date plain on an ordinary day', (tester) async {
    // 2000-01-01 is 24 Ramadan — not a Sunnah occasion.
    await _pumpSheet(tester, base: DateTime(2000, 1, 1));
    final hijri = tester.widget<Text>(find.text('24 Ramadan 1420 AH'));
    expect(hijri.style?.color, isNot(const Color(0xFF9C6F02)));
    expect(hijri.style?.fontWeight, isNot(FontWeight.w700));
  });
}
