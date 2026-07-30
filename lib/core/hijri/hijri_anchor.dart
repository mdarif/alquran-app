/// A single manually verified moon-sighting correction point: from
/// [gregorianDate] onward (until a later anchor for the same [region]
/// supersedes it), the tabular Hijri result should be shifted by
/// [correctionDays] to match the region's actual announced date.
class HijriAnchor {
  const HijriAnchor({
    required this.gregorianDate,
    required this.correctionDays,
    this.region = defaultRegion,
  });

  /// Only the y/m/d matter; time-of-day is ignored.
  final DateTime gregorianDate;
  final int correctionDays;
  final String region;

  /// The region this app's Urdu/Hindi audience is anchored to when none is
  /// specified — see the `prayer-times-creed-constraint` decision (Karachi
  /// method, hard-wired, not user-selectable).
  static const String defaultRegion = 'PK';
}

/// Pure resolution: the correction to apply for [date] in [region], given a
/// list of [anchors] (any order, any set of regions). Picks the LATEST anchor
/// whose [HijriAnchor.gregorianDate] is on or before [date] for that region;
/// returns 0 (no correction — falls back to the raw tabular algorithm) if no
/// such anchor exists. Never throws.
int resolveHijriCorrectionDays(
  DateTime date,
  List<HijriAnchor> anchors, {
  String region = HijriAnchor.defaultRegion,
}) {
  final day = DateTime(date.year, date.month, date.day);
  HijriAnchor? best;
  for (final a in anchors) {
    if (a.region != region) continue;
    final aDay = DateTime(
      a.gregorianDate.year,
      a.gregorianDate.month,
      a.gregorianDate.day,
    );
    if (aDay.isAfter(day)) continue;
    if (best == null) {
      best = a;
      continue;
    }
    final bestDay = DateTime(
      best.gregorianDate.year,
      best.gregorianDate.month,
      best.gregorianDate.day,
    );
    if (aDay.isAfter(bestDay)) best = a;
  }
  return best?.correctionDays ?? 0;
}
