import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/entities/prayer.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 6, 23);
DateTime _t(int h, [int m = 0]) => _base.add(Duration(hours: h, minutes: m));

final _day = DailyPrayerTimes(
  fajr: _t(4, 30),
  sunrise: _t(6),
  dhuhr: _t(12, 15),
  asr: _t(15, 30),
  maghrib: _t(18, 45),
  isha: _t(20, 15),
  location: const GeoLocation(latitude: 24.45, longitude: 54.38),
  date: _base,
);

void main() {
  group('DailyPrayerTimes', () {
    test('schedule is the 5 obligatory prayers in order (no sunrise)', () {
      expect(
        _day.schedule.map((e) => e.$1).toList(),
        [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha],
      );
    });

    test('nextAfter returns the next upcoming prayer', () {
      expect(_day.nextAfter(_t(3))?.$1, Prayer.fajr); // before dawn
      expect(_day.nextAfter(_t(13))?.$1, Prayer.asr); // after Dhuhr
      expect(_day.nextAfter(_t(19))?.$1, Prayer.isha); // after Maghrib
    });

    test('a time exactly at a prayer returns the FOLLOWING prayer', () {
      expect(_day.nextAfter(_day.asr)?.$1, Prayer.maghrib);
      expect(_day.nextAfter(_day.isha), isNull);
    });

    test('nextAfter is null once all of the day has passed', () {
      expect(_day.nextAfter(_t(23)), isNull);
    });
  });
}
