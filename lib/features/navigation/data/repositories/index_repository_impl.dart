import '../../../../core/database/app_database.dart';
import '../../domain/entities/index_entry.dart';
import '../../domain/entities/index_kind.dart';
import '../../domain/repositories/index_repository.dart';

class IndexRepositoryImpl implements IndexRepository {
  const IndexRepositoryImpl(this._db);

  final AppDatabase _db;

  static const Map<IndexKind, String> _columns = {
    IndexKind.juz: 'juz_number',
    IndexKind.hizb: 'hizb_number',
    IndexKind.page: 'page_number',
    IndexKind.ruku: 'ruku_number',
  };

  @override
  Future<List<IndexEntry>> entries(IndexKind kind) async {
    final starts = await _db.indexStarts(_columns[kind]!);
    final names = {
      for (final s in await _db.allSurahs()) s.id: s.nameEnglish,
    };
    return [
      for (final s in starts)
        IndexEntry(
          number: s.index,
          startSurahId: s.surahId,
          startSurahName: names[s.surahId] ?? 'Surah ${s.surahId}',
          startAyah: s.ayahNumber,
        ),
    ];
  }
}
