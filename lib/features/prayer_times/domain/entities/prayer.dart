/// The five obligatory prayers. (Sunrise is tracked separately on
/// [DailyPrayerTimes] — it bounds the Fajr light phase but is not a salah, and
/// the next-prayer indicator never points at it.)
enum Prayer {
  fajr('Fajr'),
  dhuhr('Dhuhr'),
  asr('Asr'),
  maghrib('Maghrib'),
  isha('Isha');

  const Prayer(this.label);

  /// Display name (English; the audience reads these as proper nouns).
  final String label;
}
