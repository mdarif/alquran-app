import 'mushaf_palette.dart';

/// Maps the day's prayer boundaries to a [DayPhase] — the "Light of Day" surface
/// tracking the *real* prayers rather than fixed clock hours.
///
/// Pure and **core-only**: it takes primitive [DateTime]s (not the prayer-times
/// feature's value object), so `core/theme` never imports a feature. The DI
/// closure adapts the feature's `DailyPrayerTimes` into these five boundaries.
///
/// Windows: `[fajr,sunrise)`→fajr (dawn), `[sunrise,asr)`→duha (bright day, incl.
/// Dhuhr), `[asr,maghrib)`→asr, `[maghrib,isha)`→maghrib (dusk), and before Fajr
/// or after Isha → isha (night).
DayPhase phaseForBoundaries({
  required DateTime fajr,
  required DateTime sunrise,
  required DateTime asr,
  required DateTime maghrib,
  required DateTime isha,
  required DateTime now,
}) {
  if (now.isBefore(fajr)) return DayPhase.isha; // pre-dawn is still night
  if (now.isBefore(sunrise)) return DayPhase.fajr;
  if (now.isBefore(asr)) return DayPhase.duha;
  if (now.isBefore(maghrib)) return DayPhase.asr;
  if (now.isBefore(isha)) return DayPhase.maghrib;
  return DayPhase.isha;
}
