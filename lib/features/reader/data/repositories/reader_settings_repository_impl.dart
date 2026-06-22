import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/reader_settings_repository.dart';

class ReaderSettingsRepositoryImpl implements ReaderSettingsRepository {
  const ReaderSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kFontSize = 'reader_font_size';
  static const String _kDetailed = 'reader_detailed';
  static const String _kPeekLang = 'reader_peek_translation';

  @override
  double get fontSize =>
      _prefs.getDouble(_kFontSize) ?? ReaderSettingsRepository.defaultFontSize;

  @override
  bool get detailed => _prefs.getBool(_kDetailed) ?? false;

  @override
  String? get peekTranslation => _prefs.getString(_kPeekLang);

  @override
  Future<void> setFontSize(double value) => _prefs.setDouble(_kFontSize, value);

  @override
  Future<void> setDetailed(bool value) => _prefs.setBool(_kDetailed, value);

  @override
  Future<void> setPeekTranslation(String languageCode) =>
      _prefs.setString(_kPeekLang, languageCode);
}
