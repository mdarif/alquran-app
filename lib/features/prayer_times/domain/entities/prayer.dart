/// A daily time marker. Five are the obligatory prayers (salah). [sunrise] is
/// NOT a salah — it's the end of the Fajr window, so it surfaces as the "next"
/// marker during dawn (after Fajr, before sunrise) and is listed in the sheet.
/// It is deliberately excluded from [DailyPrayerTimes.schedule] (the salah list)
/// but included in the next-marker sequence that [DailyPrayerTimes.nextAfter]
/// walks.
enum Prayer {
  fajr('Fajr'),
  sunrise('Sunrise'),
  dhuhr('Dhuhr'),
  asr('Asr'),
  maghrib('Maghrib'),
  isha('Isha');

  const Prayer(this.label);

  /// Whether this marker is one of the five obligatory prayers (sunrise is not).
  bool get isSalah => this != Prayer.sunrise;

  /// Display name (English; the audience reads these as proper nouns).
  final String label;
}
