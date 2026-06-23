import 'package:al_quran/features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'package:al_quran/features/prayer_times/domain/entities/forbidden_window.dart';
import 'package:al_quran/features/prayer_times/domain/entities/geo_location.dart';
import 'package:al_quran/features/prayer_times/domain/entities/prayer.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 6, 23);
DateTime _t(int h, [int m = 0]) => _base.add(Duration(hours: h, minutes: m));

// Sunrise/Maghrib symmetric about Dhuhr so solar noon == Dhuhr (as in real
// data), keeping the zenith forbidden window valid.
final _day = DailyPrayerTimes(
  fajr: _t(4, 30),
  sunrise: _t(6),
  dhuhr: _t(12, 15),
  asr: _t(15, 30),
  maghrib: _t(18, 30),
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

    test('in the dawn window (Fajr→sunrise) the next marker is Sunrise', () {
      // Fajr 4:30, sunrise 6:00 — sunrise marks when the Fajr window expires.
      expect(_day.nextAfter(_t(5))?.$1, Prayer.sunrise); // mid-dawn
      expect(_day.nextAfter(_t(5))?.$2, _day.sunrise);
      expect(_day.nextAfter(_t(7))?.$1, Prayer.dhuhr); // after sunrise → Dhuhr
    });

    test('a time exactly at a prayer returns the FOLLOWING prayer', () {
      expect(_day.nextAfter(_day.asr)?.$1, Prayer.maghrib);
      expect(_day.nextAfter(_day.isha), isNull);
    });

    test('nextAfter is null once all of the day has passed', () {
      expect(_day.nextAfter(_t(23)), isNull);
    });

    test('forbiddenWindows are the three periods in clock order', () {
      expect(
        _day.forbiddenWindows.map((w) => w.reason).toList(),
        [
          ForbiddenReason.afterSunrise,
          ForbiddenReason.zenith,
          ForbiddenReason.beforeSunset,
        ],
      );
      // After sunrise: 6:00 → 6:15 (the ~spear's-length span).
      expect(_day.forbiddenWindows.first.start, _day.sunrise);
      expect(_day.forbiddenWindows.first.end, _t(6, 15));
      // Zenith ends at Dhuhr (zawāl); before-sunset ends at Maghrib.
      expect(_day.forbiddenWindows[1].end, _day.dhuhr);
      expect(_day.forbiddenWindows.last.end, _day.maghrib);
    });

    test('forbiddenAt reports the active window, else null', () {
      expect(_day.forbiddenAt(_t(6, 5))?.reason, ForbiddenReason.afterSunrise);
      expect(_day.forbiddenAt(_t(12, 13))?.reason, ForbiddenReason.zenith);
      expect(
        _day.forbiddenAt(_t(18, 20))?.reason,
        ForbiddenReason.beforeSunset,
      );
      expect(_day.forbiddenAt(_t(10)), isNull); // mid-morning — permitted
      expect(_day.forbiddenAt(_day.dhuhr), isNull); // zawāl ends it
    });
  });
}
