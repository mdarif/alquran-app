part of 'reader_cubit.dart';

enum ReaderStatus { initial, loading, loaded, error }

class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.ayahs = const [],
    this.resources = const [],
    this.headings = const {},
    this.error,
  });

  final ReaderStatus status;
  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Map<int, SurahHeading> headings;
  final String? error;

  ReaderState copyWith({
    ReaderStatus? status,
    List<Ayah>? ayahs,
    List<TranslationResource>? resources,
    Map<int, SurahHeading>? headings,
    String? error,
  }) {
    return ReaderState(
      status: status ?? this.status,
      ayahs: ayahs ?? this.ayahs,
      resources: resources ?? this.resources,
      headings: headings ?? this.headings,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, ayahs, resources, headings, error];
}
