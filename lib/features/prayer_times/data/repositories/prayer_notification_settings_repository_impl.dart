import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/prayer_notification_settings_repository.dart';

class PrayerNotificationSettingsRepositoryImpl
    implements PrayerNotificationSettingsRepository {
  PrayerNotificationSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kEnabled = 'prayer_notifications_enabled';

  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? false;

  @override
  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_kEnabled, value);
  }
}

