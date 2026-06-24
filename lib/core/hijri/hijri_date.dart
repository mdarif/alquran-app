/// An Islamic (Hijri) calendar date, converted from a Gregorian date with the
/// standard tabular (Kuwaiti) algorithm — pure, offline, deterministic. The
/// tabular calendar can differ from a local moon-sighting by a day, so callers
/// may pass an [adjustmentDays] correction.
class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day});

  /// Convert a Gregorian [date] (only its y/m/d are used) to Hijri, shifting by
  /// [adjustmentDays] first (− earlier · + later).
  factory HijriDate.fromGregorian(DateTime date, {int adjustmentDays = 0}) {
    final d = DateTime(date.year, date.month, date.day)
        .add(Duration(days: adjustmentDays));
    return _fromJdn(_gregorianToJdn(d.year, d.month, d.day));
  }

  final int year; // Hijri year (AH)
  final int month; // 1..12
  final int day; // 1..30

  /// English month name (Muharram … Dhu al-Hijjah).
  String get monthName => _months[month - 1];

  /// `07 Muharram 1448 AH` — zero-padded day · month · year · the AH marker.
  String get formatted =>
      '${day.toString().padLeft(2, '0')} $monthName $year AH';

  // --- Conversion (integer Kuwaiti algorithm; matches PHP/JS Hijri calcs). ---

  static int _gregorianToJdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
  }

  static HijriDate _fromJdn(int jdn) {
    var l = jdn - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year: year, month: month, day: day);
  }

  static const List<String> _months = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qa'dah",
    'Dhu al-Hijjah',
  ];
}
