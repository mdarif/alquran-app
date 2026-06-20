/// Compile-time feature flags. We're fully offline (no remote config), so these
/// are simple constants — flip and rebuild.
abstract final class FeatureFlags {
  /// Page / Juz / Hizb / Ruku navigation, surfaced via the home "Jump to" sheet.
  /// Surah browsing is always available. Set false for a Surah-only experience.
  static const bool advancedNavigation = true;
}
