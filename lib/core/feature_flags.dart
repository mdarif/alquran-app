/// Compile-time feature flags. We're fully offline (no remote config), so these
/// are simple constants — flip and rebuild.
abstract final class FeatureFlags {
  /// Page / Juz / Hizb / Ruku navigation, surfaced via the home "Jump to" sheet.
  /// Surah browsing is always available. Off for a Surah-only experience — keeps
  /// the reading-first home dead simple. The capability/code is retained (PRD
  /// MVP nav); flip back to true to resurface it.
  static const bool advancedNavigation = false;

  /// IndoPak (South-Asian Naskh) script option in the reader — the standard-
  /// Unicode `text_arabic_indopak` column rendered in the Noorehuda font,
  /// alongside the default KFGQPC Uthmani. Shipped DARK: while false the reader
  /// is Uthmani-only and every path resolves exactly as before (the DB column
  /// just sits unused). Flip to true to surface the Uthmani/IndoPak toggle once
  /// the font + UX are signed off on device.
  static const bool indopakScript = true;

  /// Prayer times across the app: the Home app-bar next-prayer pill, the all-five
  /// times sheet, the forbidden-window caution, and the prayer-AWARE tint of
  /// "Light of Day" (the surface snaps to your real Fajr/Sunrise/Asr/Maghrib/Isha
  /// boundaries). Shipped DARK for v1: while false the pill never appears, no
  /// location is ever requested, and the theme falls back to clock-hour phases
  /// (Light of Day stays on, just time-of-day rather than prayer-driven). The
  /// PrayerTimesCubit/repo stay registered (lazily, untouched) so flipping this
  /// survives a hot reload. Flip to true to surface prayer times.
  static const bool prayerTimes = true;

  /// Home-screen widgets (Android `PrayerWidgetProvider` + `PrayerScheduleWidget`,
  /// iOS WidgetKit `PrayerWidget`/`PrayerScheduleWidget`). Shipped DARK for v1:
  /// while false the app never publishes a payload to or refreshes the OS widgets
  /// — they stay empty. NOTE: this Dart flag only stops the app FEEDING the
  /// widgets; the native widget targets still exist in the build and would appear
  /// (blank) in the OS widget gallery. To keep them out of v1 entirely, also drop
  /// the iOS widget extension target and the Android `<receiver>` registrations.
  static const bool homeScreenWidgets = false;

  /// In-app, single-ayah audio recitation (Mishary Rashid Alafasy), streamed
  /// from the islamic.network CDN and cached to disk for offline replay. Shipped
  /// DARK: while false the reader shows no play affordance, the audio cubit/player
  /// is never constructed, and zero network code runs — the app stays fully
  /// offline. Flip to true once on-device playback and the audio source's
  /// licensing are signed off (see the plan + ATTRIBUTION).
  static const bool audioRecitation = false;
}
