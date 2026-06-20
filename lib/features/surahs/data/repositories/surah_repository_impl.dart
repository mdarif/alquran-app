import '../../../../core/database/app_database.dart';
import '../../domain/entities/surah.dart';
import '../../domain/repositories/surah_repository.dart';

class SurahRepositoryImpl implements SurahRepository {
  const SurahRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Surah>> getSurahs() async {
    final rows = await _db.allSurahs();
    return rows
        .map(
          (r) => Surah(
            id: r.id,
            nameArabic: r.nameArabic,
            nameEnglish: r.nameEnglish,
            totalAyahs: r.totalAyahs,
            revelationPlace: r.revelationPlace,
          ),
        )
        .toList();
  }
}
