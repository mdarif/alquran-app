part of 'surah_list_cubit.dart';

enum SurahListStatus { initial, loading, loaded, error }

class SurahListState extends Equatable {
  const SurahListState({
    this.status = SurahListStatus.initial,
    this.surahs = const [],
    this.error,
  });

  final SurahListStatus status;
  final List<Surah> surahs;
  final String? error;

  SurahListState copyWith({
    SurahListStatus? status,
    List<Surah>? surahs,
    String? error,
  }) {
    return SurahListState(
      status: status ?? this.status,
      surahs: surahs ?? this.surahs,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, surahs, error];
}
