part of 'surah_list_cubit.dart';

enum SurahListStatus { initial, loading, loaded, error }

class SurahListState extends Equatable {
  const SurahListState({
    this.status = SurahListStatus.initial,
    this.surahs = const [],
    this.query = '',
    this.error,
  });

  final SurahListStatus status;

  /// The full 114-surah list (unfiltered).
  final List<Surah> surahs;

  /// The live search query; empty shows every surah. See [visibleSurahs].
  final String query;
  final String? error;

  /// The results to render: [surahs] narrowed by [query], best matches first,
  /// each optionally carrying a verse to open at (for "18:5"-style queries).
  List<SurahHit> get visibleHits => searchSurahs(surahs, query);

  /// The visible surahs without their verse annotations (convenience).
  List<Surah> get visibleSurahs => [for (final h in visibleHits) h.surah];

  SurahListState copyWith({
    SurahListStatus? status,
    List<Surah>? surahs,
    String? query,
    String? error,
  }) {
    return SurahListState(
      status: status ?? this.status,
      surahs: surahs ?? this.surahs,
      query: query ?? this.query,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, surahs, query, error];
}
