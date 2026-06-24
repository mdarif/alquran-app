import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/arabic_script.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class ReaderSettingsRepositoryImpl implements ReaderSettingsRepository {
  const ReaderSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kFontSize = 'reader_font_size';
  static const String _kDetailed = 'reader_detailed';
  static const String _kSelectedLangs = 'reader_selected_translations';
  static const String _kScript = 'reader_script';

  @override
  ArabicScript get script => _prefs.getString(_kScript) == 'indopak'
      ? ArabicScript.indopak
      : ArabicScript.uthmani;

  @override
  Future<void> setScript(ArabicScript value) =>
      _prefs.setString(_kScript, value.name);

  @override
  double get fontSize =>
      _prefs.getDouble(_kFontSize) ?? ReaderSettingsRepository.defaultFontSize;

  @override
  bool get detailed => _prefs.getBool(_kDetailed) ?? false;

  @override
  List<String>? get selectedTranslations =>
      _prefs.getStringList(_kSelectedLangs);

  @override
  Future<void> setFontSize(double value) => _prefs.setDouble(_kFontSize, value);

  @override
  Future<void> setDetailed(bool value) => _prefs.setBool(_kDetailed, value);

  @override
  Future<void> setSelectedTranslations(List<String> languageCodes) =>
      _prefs.setStringList(_kSelectedLangs, languageCodes);
}
