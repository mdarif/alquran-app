part of 'reader_cubit.dart';

enum ReaderStatus { initial, loading, loaded, error }

class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.ayahs = const [],
    this.resources = const [],
    this.headings = const {},
    this.error,
    this.cacheEpoch = 0,
  });

  final ReaderStatus status;
  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Map<int, SurahHeading> headings;
  final String? error;

  /// Bumped whenever the section cache gains an entry, so widgets that render
  /// straight from the cache (the PageView's section pages) rebuild and pick
  /// it up. Without this, a page that missed the cache shows a spinner that
  /// nothing ever wakes — a background warm() fills the cache silently.
  final int cacheEpoch;

  ReaderState copyWith({
    ReaderStatus? status,
    List<Ayah>? ayahs,
    List<TranslationResource>? resources,
    Map<int, SurahHeading>? headings,
    String? error,
    int? cacheEpoch,
  }) {
    return ReaderState(
      status: status ?? this.status,
      ayahs: ayahs ?? this.ayahs,
      resources: resources ?? this.resources,
      headings: headings ?? this.headings,
      error: error,
      cacheEpoch: cacheEpoch ?? this.cacheEpoch,
    );
  }

  @override
  List<Object?> get props =>
      [status, ayahs, resources, headings, error, cacheEpoch];
}
