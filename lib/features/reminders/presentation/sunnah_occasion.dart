import '../../../core/feature_flags.dart';
import '../domain/scheduling/occurrence_engine.dart';

/// The Sunnah occasion name for [base] (the Maghrib-rolled day) — e.g. `Ashura`
/// on 9/10 Muharram — or null on an ordinary day or when the feature is gated
/// off. Drives the "special date" gilding of the Hijri date (no extra UI; the
/// date itself just turns gold + a touch bolder). Reuses the reminders registry
/// so the highlight stays in step with the notifications.
String? sunnahOccasionName(DateTime base) => FeatureFlags.sunnahOccasions
    ? const OccurrenceEngine().occasionOn(base)?.occasion
    : null;
