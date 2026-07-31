/// Remote JSON file used by the soft app-update reminder.
///
/// Expected shape:
/// {
///   "latestVersion": "1.2.2",
///   "minimumSupportedVersion": "1.0.0",
///   "storeUrl": "https://play.google.com/store/apps/details?id=com.almarfa.alquran",
///   "message": "A newer version of Al Quran is available."
/// }
///
/// Overridable at build time for staging:
///
///     flutter run --dart-define=APP_UPDATE_CONFIG_URL=https://.../app-update.json
const String appUpdateConfigUrl = String.fromEnvironment(
  'APP_UPDATE_CONFIG_URL',
  defaultValue: 'https://alquranreader.com/app-update.json',
);

const String androidPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.almarfa.alquran';
