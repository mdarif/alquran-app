abstract interface class PrayerNotificationSettingsRepository {
  bool get enabled;
  bool get allowZoneMismatchAlerts;
  Future<void> setEnabled(bool value);
  Future<void> setAllowZoneMismatchAlerts(bool value);
}
