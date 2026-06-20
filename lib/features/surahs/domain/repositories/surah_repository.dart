import '../entities/surah.dart';

abstract interface class SurahRepository {
  Future<List<Surah>> getSurahs();
}
