import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/repositories/last_read_repository.dart';

class LastReadRepositoryImpl implements LastReadRepository {
  const LastReadRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kDimension = 'last_read_dimension';
  static const String _kValue = 'last_read_value';
  static const String _kTitle = 'last_read_title';
  static const String _kAyahId = 'last_read_ayah_id';
  static const String _kSurahId = 'last_read_surah_id';
  static const String _kAyahNumber = 'last_read_ayah_number';

  @override
  Future<void> save(LastRead value) async {
    await _prefs.setInt(_kDimension, value.target.dimension.index);
    await _prefs.setInt(_kValue, value.target.value);
    await _prefs.setString(_kTitle, value.target.title);
    await _prefs.setInt(_kAyahId, value.ayahId);
    await _prefs.setInt(_kSurahId, value.surahId);
    await _prefs.setInt(_kAyahNumber, value.ayahNumber);
  }

  @override
  Future<LastRead?> load() async {
    final dimension = _prefs.getInt(_kDimension);
    final value = _prefs.getInt(_kValue);
    final title = _prefs.getString(_kTitle);
    final ayahId = _prefs.getInt(_kAyahId);
    final surahId = _prefs.getInt(_kSurahId);
    final ayahNumber = _prefs.getInt(_kAyahNumber);
    // All fields are required to resume to an exact verse. A pre-verse record
    // (older app version) is treated as "nothing read"; it repopulates on the
    // next read.
    if (dimension == null ||
        value == null ||
        title == null ||
        ayahId == null ||
        surahId == null ||
        ayahNumber == null) {
      return null;
    }
    if (dimension < 0 || dimension >= ReaderDimension.values.length) {
      return null;
    }
    return LastRead(
      target: ReaderTarget(
        dimension: ReaderDimension.values[dimension],
        value: value,
        title: title,
      ),
      ayahId: ayahId,
      surahId: surahId,
      ayahNumber: ayahNumber,
    );
  }
}
