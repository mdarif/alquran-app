import 'prayer.dart';

/// The upcoming prayer plus how long until it — the view the indicator renders.
/// [remaining] is computed by the cubit from its injected clock (clamped ≥ 0).
class NextPrayer {
  const NextPrayer({
    required this.prayer,
    required this.at,
    required this.remaining,
  });

  final Prayer prayer;
  final DateTime at; // local
  final Duration remaining;
}
