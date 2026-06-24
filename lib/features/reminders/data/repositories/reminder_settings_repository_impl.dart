import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/reminder_settings_repository.dart';

class ReminderSettingsRepositoryImpl implements ReminderSettingsRepository {
  const ReminderSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kEnabled = 'reminders_enabled';

  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? false;

  @override
  Future<void> setEnabled(bool value) => _prefs.setBool(_kEnabled, value);
}
