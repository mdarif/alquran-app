import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/reader_settings_repository.dart';

class ReaderSettingsRepositoryImpl implements ReaderSettingsRepository {
  const ReaderSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kFontSize = 'reader_font_size';
  static const String _kDetailed = 'reader_detailed';

  @override
  double get fontSize =>
      _prefs.getDouble(_kFontSize) ?? ReaderSettingsRepository.defaultFontSize;

  @override
  bool get detailed => _prefs.getBool(_kDetailed) ?? false;

  @override
  Future<void> setFontSize(double value) => _prefs.setDouble(_kFontSize, value);

  @override
  Future<void> setDetailed(bool value) => _prefs.setBool(_kDetailed, value);
}
