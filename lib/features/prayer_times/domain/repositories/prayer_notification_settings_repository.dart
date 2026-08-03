abstract interface class PrayerNotificationSettingsRepository {
  bool get enabled;
  Future<void> setEnabled(bool value);
}

