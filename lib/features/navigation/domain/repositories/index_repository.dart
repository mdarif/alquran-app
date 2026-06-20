import '../entities/index_entry.dart';
import '../entities/index_kind.dart';

abstract interface class IndexRepository {
  /// All entries for an index dimension (juz/hizb/page/ruku), each labelled with
  /// the surah/ayah where it begins.
  Future<List<IndexEntry>> entries(IndexKind kind);
}
