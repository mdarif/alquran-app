import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class ReaderSettingsRepositoryImpl implements ReaderSettingsRepository {
  const ReaderSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kFontSize = 'reader_font_size';
  static const String _kDetailed = 'reader_detailed';
  // Holds edition SLUGS. Kept under its original key so a returning reader's
  // list survives the upgrade; [migrateSelectedTranslations] rewrites the old
  // language codes in place on first launch.
  static const String _kSelectedLangs = 'reader_selected_translations';
  static const String _kSelectionMigrated = 'reader_selection_slug_migrated';
  static const String _kScript = 'reader_script';
  static const String _kRecitationSpeed = 'reader_recitation_speed';
  static const String _kShowTranslationPeek = 'reader_show_translation_peek';
  static const String _kShowArabicMatn = 'reader_show_arabic_matn';

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
  Future<void> setSelectedTranslations(List<String> slugs) =>
      _prefs.setStringList(_kSelectedLangs, slugs);

  @override
  Future<void> migrateSelectedTranslations(
    List<TranslationResource> available,
  ) async {
    if (_prefs.getBool(_kSelectionMigrated) ?? false) return;
    final saved = _prefs.getStringList(_kSelectedLangs);

    if (saved != null && saved.isNotEmpty) {
      // The old list held language codes ('ur', 'en'). Map each to an edition of
      // that language — the default one where the language now offers several,
      // since we cannot know which the reader would have picked.
      //
      // Dropping the selection instead would look to the reader like the app
      // forgot their choice, and silently re-selecting nothing would leave the
      // Detailed view with bare Arabic.
      final migrated = <String>[];
      for (final entry in saved) {
        // Already a slug — a partly-migrated install, or a fresh one.
        if (available.any((r) => r.slug == entry)) {
          migrated.add(entry);
          continue;
        }
        final matches =
            available.where((r) => r.languageCode == entry).toList();
        if (matches.isEmpty) continue; // language no longer shipped
        final pick = matches.firstWhere(
          (r) => r.defaultOn,
          orElse: () => matches.first,
        );
        if (!migrated.contains(pick.slug)) migrated.add(pick.slug);
      }
      if (migrated.isNotEmpty) {
        await _prefs.setStringList(_kSelectedLangs, migrated);
      }
    }
    await _prefs.setBool(_kSelectionMigrated, true);
  }

  @override
  double get recitationSpeed =>
      _prefs.getDouble(_kRecitationSpeed) ??
      ReaderSettingsRepository.defaultRecitationSpeed;

  @override
  bool get showTranslationPeek =>
      _prefs.getBool(_kShowTranslationPeek) ?? false;

  @override
  bool get showArabicMatn => _prefs.getBool(_kShowArabicMatn) ?? true;

  @override
  Future<void> setRecitationSpeed(double value) =>
      _prefs.setDouble(_kRecitationSpeed, value);

  @override
  Future<void> setShowTranslationPeek(bool value) =>
      _prefs.setBool(_kShowTranslationPeek, value);

  @override
  Future<void> setShowArabicMatn(bool value) =>
      _prefs.setBool(_kShowArabicMatn, value);
}
