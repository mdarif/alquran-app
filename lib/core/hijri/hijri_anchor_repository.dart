import '../database/app_database.dart';
import 'hijri_anchor.dart';

/// Loads [HijriAnchorPoints] once at startup into memory so every synchronous
/// UI build (Hijri dateline, prayer sheet) can resolve a correction without an
/// await. DB-backed, but every read is defensive: a missing table, a corrupt
/// row, or a query throwing for any reason all degrade to "no correction" (the
/// raw tabular calendar) rather than crashing or blocking the date from
/// rendering at all.
class HijriAnchorRepository {
  HijriAnchorRepository(this._db);

  final AppDatabase _db;
  List<HijriAnchor> _anchors = const [];

  /// Loads all anchor rows into memory. Call once at startup (before the first
  /// frame that shows a Hijri date, ideally); safe to call again to refresh
  /// after a DB re-seed. Never throws — on any failure (missing table from an
  /// older bundled DB, corrupt row, etc.) it leaves anchors empty, which makes
  /// [correctionDaysFor] fall back to the base tabular algorithm.
  Future<void> preload() async {
    List<HijriAnchorPointRow> rows;
    try {
      rows = await _db.select(_db.hijriAnchorPoints).get();
    } catch (_) {
      // Table missing entirely (older bundled DB) or the query itself failed.
      _anchors = const [];
      return;
    }
    // Parse defensively PER ROW: one malformed date (a pipeline bug) must not
    // discard every other, correctly-formed anchor.
    final parsed = <HijriAnchor>[];
    for (final r in rows) {
      try {
        parsed.add(
          HijriAnchor(
            gregorianDate: DateTime.parse(r.gregorianDate),
            correctionDays: r.correctionDays,
            region: r.region,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    _anchors = List.unmodifiable(parsed);
  }

  /// Synchronous — resolves against the in-memory snapshot loaded by
  /// [preload]. Strictly prefers a DB anchor over the mathematical (tabular)
  /// fallback: if an anchor applies, its value is used as-is, never blended
  /// with or overridden by the algorithm.
  int correctionDaysFor(
    DateTime date, {
    String region = HijriAnchor.defaultRegion,
  }) =>
      resolveHijriCorrectionDays(date, _anchors, region: region);
}
