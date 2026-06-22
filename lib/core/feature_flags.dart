/// Compile-time feature flags. We're fully offline (no remote config), so these
/// are simple constants — flip and rebuild.
abstract final class FeatureFlags {
  /// Page / Juz / Hizb / Ruku navigation, surfaced via the home "Jump to" sheet.
  /// Surah browsing is always available. Off for a Surah-only experience — keeps
  /// the reading-first home dead simple. The capability/code is retained (PRD
  /// MVP nav); flip back to true to resurface it.
  static const bool advancedNavigation = false;
}
