import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/reader_target.dart';
import '../../domain/repositories/last_read_repository.dart';

class LastReadRepositoryImpl implements LastReadRepository {
  const LastReadRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _kDimension = 'last_read_dimension';
  static const String _kValue = 'last_read_value';
  static const String _kTitle = 'last_read_title';

  @override
  Future<void> save(ReaderTarget target) async {
    await _prefs.setInt(_kDimension, target.dimension.index);
    await _prefs.setInt(_kValue, target.value);
    await _prefs.setString(_kTitle, target.title);
  }

  @override
  Future<ReaderTarget?> load() async {
    final dimension = _prefs.getInt(_kDimension);
    final value = _prefs.getInt(_kValue);
    final title = _prefs.getString(_kTitle);
    if (dimension == null || value == null || title == null) return null;
    if (dimension < 0 || dimension >= ReaderDimension.values.length) {
      return null;
    }
    return ReaderTarget(
      dimension: ReaderDimension.values[dimension],
      value: value,
      title: title,
    );
  }
}
