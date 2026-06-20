part of 'index_list_cubit.dart';

enum IndexListStatus { initial, loading, loaded, error }

class IndexListState extends Equatable {
  const IndexListState({
    this.status = IndexListStatus.initial,
    this.entries = const [],
    this.error,
  });

  final IndexListStatus status;
  final List<IndexEntry> entries;
  final String? error;

  IndexListState copyWith({
    IndexListStatus? status,
    List<IndexEntry>? entries,
    String? error,
  }) {
    return IndexListState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, entries, error];
}
