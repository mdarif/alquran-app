/// An Islamic (Hijri) calendar date, converted from a Gregorian date with the
/// standard tabular (Kuwaiti) algorithm — pure, offline, deterministic. The
/// tabular calendar can differ from a local moon-sighting by a day, so callers
/// pass an [adjustmentDays] correction to align with the local sighting (e.g. a
/// subcontinental Ahle-Hadith one). Rendering is Urdu-first (month names +
/// Urdu-Indic numerals U+06F0, the digits Urdu readers expect — NOT Arabic-Indic
/// U+0660).
class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day});

  /// Convert a Gregorian [date] (only its y/m/d are used) to Hijri, shifting by
  /// [adjustmentDays] first (− earlier · + later) to match a local sighting.
  factory HijriDate.fromGregorian(DateTime date, {int adjustmentDays = 0}) {
    final d = DateTime(date.year, date.month, date.day)
        .add(Duration(days: adjustmentDays));
    return _fromJdn(_gregorianToJdn(d.year, d.month, d.day));
  }

  final int year; // Hijri year (AH)
  final int month; // 1..12
  final int day; // 1..30

  /// Urdu month name (محرم … ذی الحجہ).
  String get urduMonth => _urduMonths[month - 1];

  /// `۹ ذی الحجہ ۱۴۴۷ھ` — day · Urdu month · year · the Hijri marker (ھ).
  String get urduLong => '${_urduDigits(day)} $urduMonth ${_urduDigits(year)}ھ';

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

  static String _urduDigits(int n) => n
      .toString()
      .split('')
      .map((c) => String.fromCharCode(0x06F0 + c.codeUnitAt(0) - 0x30))
      .join();

  static const List<String> _urduMonths = [
    'محرم',
    'صفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاول',
    'جمادی الثانی',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذی القعدہ',
    'ذی الحجہ',
  ];
}
